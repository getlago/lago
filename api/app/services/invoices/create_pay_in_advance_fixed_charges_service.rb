# frozen_string_literal: true

module Invoices
  class CreatePayInAdvanceFixedChargesService < BaseService
    Result = BaseResult[:invoice]

    def initialize(subscription:, timestamp:)
      @subscription = subscription
      @timestamp = timestamp
      @customer = subscription.customer
      @organization = subscription.organization

      super
    end

    def call
      return result unless subscription.active? || subscription.gated?
      return result if fixed_charge_events.empty?

      # Calculate fees for all fixed charge events
      fees = calculate_all_fees
      # Invoice without fees should be created if there are no fees to bill
      # return result if fees.empty?

      tax_deferred = false

      ActiveRecord::Base.transaction do
        create_generating_invoice
        invoice.status = :open if subscription.gated?
        fees.each do |fee|
          fee.invoice = invoice
          fee.save!
        end

        invoice.fees_amount_cents = invoice.fees.sum(:amount_cents)
        invoice.sub_total_excluding_taxes_amount_cents = invoice.fees_amount_cents
        Credits::AppliedCouponsService.call(invoice:) if invoice.fees_amount_cents&.positive?

        # NOTE: Custom sections are applied before computing taxes so they are persisted even when
        #       tax computation is deferred to a tax provider (the `next` below skips the rest of the block).
        Invoices::ApplyInvoiceCustomSectionsService.call(invoice:, resources: [subscription])

        totals_result = Invoices::ComputeTaxesAndTotalsService.call(invoice:)
        if totals_result.failure? && totals_result.error.is_a?(BaseService::UnknownTaxFailure)
          tax_deferred = true
          next
        end
        totals_result.raise_if_error!

        create_credit_note_credit
        create_applied_prepaid_credit if should_create_applied_prepaid_credit?

        skip_payment_gating_for_zero_amount if subscription.payment_gated? && invoice.total_amount_cents.zero? && !invoice.tax_pending?

        invoice.payment_status = invoice.total_amount_cents.positive? ? :pending : :succeeded
        Invoices::TransitionToFinalStatusService.call(invoice:)
        invoice.save!
      end

      result.invoice = invoice

      if tax_deferred
        deliver_fee_webhooks
        return result
      end

      if subscription.gated?
        Invoices::Payments::CreateService.call_async(invoice:)
      elsif !invoice.closed?
        Utils::SegmentTrack.invoice_created(invoice)
        deliver_webhooks
        Utils::ActivityLog.produce(invoice, "invoice.created")
        Invoices::GenerateDocumentsJob.perform_later(invoice:, notify: should_deliver_email?)
        Integrations::Aggregator::Invoices::CreateJob.perform_later(invoice:) if invoice.should_sync_invoice?
        Integrations::Aggregator::Invoices::Hubspot::CreateJob.perform_later(invoice:) if invoice.should_sync_hubspot_invoice?
        Invoices::Payments::CreateService.call_async(invoice:)
      end

      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    rescue Sequenced::SequenceError, ActiveRecord::StaleObjectError, Customers::FailedToAcquireLock
      raise
    rescue => e
      result.fail_with_error!(e)
    end

    private

    attr_reader :subscription, :timestamp, :customer, :organization
    attr_accessor :invoice

    def skip_payment_gating_for_zero_amount
      Subscriptions::ActivationRules::Payment::EvaluateService.call!(
        rule: subscription.activation_rules.payment.sole,
        status: :satisfied
      )
      Subscriptions::ActivationRules::ResolveSubscriptionStatusService.call!(subscription:)
    end

    def fixed_charge_events
      @fixed_charge_events ||= subscription
        .fixed_charge_events
        .where(
          fixed_charge: subscription.fixed_charges.pay_in_advance,
          timestamp: Time.zone.at(timestamp)
        )
    end

    def calculate_all_fees
      fees = []

      fixed_charge_events.each do |event|
        fixed_charge = event.fixed_charge
        next unless fixed_charge.pay_in_advance?

        fee_result = Fees::BuildPayInAdvanceFixedChargeService.call!(
          subscription:,
          fixed_charge:,
          fixed_charge_event: event,
          timestamp:
        )

        fees << fee_result.fee if fee_result.fee
      end

      fees
    end

    def create_generating_invoice
      invoice_result = Invoices::CreateGeneratingService.call(
        customer:,
        invoice_type: :subscription,
        currency: subscription.plan_amount_currency,
        datetime: Time.zone.at(timestamp),
        charge_in_advance: true,
        billing_entity: subscription.billing_entity || customer.billing_entity
      ) do |inv|
        Invoices::CreateInvoiceSubscriptionService
          .call(invoice: inv, subscriptions: [subscription], timestamp:, invoicing_reason: :in_advance_charge)
          .raise_if_error!
      end
      invoice_result.raise_if_error!

      @invoice = invoice_result.invoice
    end

    def deliver_webhooks
      deliver_fee_webhooks
      SendWebhookJob.perform_later("invoice.created", invoice)
    end

    def deliver_fee_webhooks
      invoice.fees.each { |f| SendWebhookJob.perform_later("fee.created", f) }
    end

    def should_deliver_email?
      License.premium? && invoice.billing_entity.email_settings.include?("invoice.finalized")
    end

    def wallets
      @wallets ||= customer.wallets.active.includes(:wallet_targets)
        .with_positive_balance.in_application_order
    end

    def should_create_applied_prepaid_credit?
      return false unless invoice.total_amount_cents&.positive?

      wallets.any?
    end

    def create_credit_note_credit
      credit_result = Credits::CreditNoteService.new(invoice:).call
      credit_result.raise_if_error!

      refresh_amounts(credit_amount_cents: credit_result.credits.sum(&:amount_cents)) if credit_result.credits
    end

    def create_applied_prepaid_credit
      prepaid_credit_result = Credits::AppliedPrepaidCreditsService.call!(invoice:)

      refresh_amounts(credit_amount_cents: prepaid_credit_result.prepaid_credit_amount_cents)
    end

    def refresh_amounts(credit_amount_cents:)
      invoice.total_amount_cents -= credit_amount_cents
    end
  end
end
