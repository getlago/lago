# frozen_string_literal: true

module Invoices
  class CreatePayInAdvanceChargeService < BaseService
    Result = BaseResult[:invoice, :invoice_id]

    def initialize(charge:, event:, timestamp:)
      @charge = charge
      @event = Events::CommonFactory.new_instance(source: event)
      @timestamp = timestamp

      super
    end

    def call
      fee_result = generate_fees
      fees = fee_result.fees
      return result if fees.none?

      tax_deferred = false

      ApplicationRecord.transaction do
        create_generating_invoice
        fees.each { |f| f.update!(invoice:) }

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

        invoice.payment_status = invoice.total_amount_cents.positive? ? :pending : :succeeded
        Invoices::TransitionToFinalStatusService.call(invoice:)
        invoice.save!
      end

      result.invoice = invoice

      if tax_deferred
        deliver_fee_webhooks
        return result
      end

      unless invoice.closed?
        Utils::SegmentTrack.invoice_created(invoice)
        deliver_webhooks
        Utils::ActivityLog.produce(invoice, "invoice.created")
        GenerateDocumentsJob.perform_later(invoice:, notify: should_deliver_email?)
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

    attr_accessor :timestamp, :charge, :event, :invoice

    delegate :subscription, to: :event
    delegate :customer, to: :subscription

    def create_generating_invoice
      invoice_result = Invoices::CreateGeneratingService.call(
        customer:,
        invoice_type: :subscription,
        currency: subscription.plan_amount_currency,
        datetime: Time.zone.at(timestamp),
        charge_in_advance: true,
        invoice_id: result.invoice_id,
        billing_entity: subscription.billing_entity || customer.billing_entity
      ) do |invoice|
        Invoices::CreateInvoiceSubscriptionService
          .call(invoice:, subscriptions: [subscription], timestamp:, invoicing_reason: :in_advance_charge)
          .raise_if_error!
      end
      invoice_result.raise_if_error!
      @invoice = invoice_result.invoice
    end

    def generate_fees
      Fees::CreatePayInAdvanceService.call!(charge:, event:, estimate: true).tap do |fee_result|
        result.invoice_id = fee_result.invoice_id
      end
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

    def should_create_applied_prepaid_credit?
      invoice.total_amount_cents&.positive?
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
