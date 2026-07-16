# frozen_string_literal: true

module Invoices
  class SubscriptionService < BaseService
    Result = BaseResult[:invoice, :non_invoiceable_fees]

    def initialize(subscriptions:, timestamp:, invoicing_reason:, invoice: nil, skip_charges: false)
      @subscriptions = subscriptions
      @timestamp = timestamp
      @invoicing_reason = invoicing_reason
      @recurring = invoicing_reason.to_sym == :subscription_periodic

      @customer = subscriptions&.first&.customer
      @currency = subscriptions&.first&.plan&.amount_currency

      # NOTE: In case of retry when the creation process failed,
      #       and if the generating invoice was persisted,
      #       the process can be retried without creating a new invoice
      @invoice = invoice
      @skip_charges = skip_charges

      super
    end

    def call
      return result if active_subscriptions.empty? && recurring

      if mixed_billing_entities?
        return result.validation_failure!(errors: {billing_entity: ["mixed_billing_entities"]})
      end

      create_generating_invoice unless invoice
      invoice.status = :open if subscription_gated?
      result.invoice = invoice

      fee_result = ActiveRecord::Base.transaction do
        context = grace_period? ? :draft : :finalize
        fee_result = Invoices::CalculateFeesService.call(
          invoice:,
          recurring:,
          context:
        )
        Invoices::ApplyInvoiceCustomSectionsService.call(invoice:, resources: subscriptions)

        skip_payment_gating_for_zero_amount if subscription_payment_gated? && invoice.total_amount_cents.zero? && !invoice.tax_pending?

        set_invoice_generated_status unless invoice.pending?
        invoice.save!

        # NOTE: We don't want to raise error and corrupt DB commit if there is tax error.
        #       In that case we want fees to stay attached to the invoice. There is retry action that will enable users
        #       to finalize invoice
        fee_result.raise_if_error! unless tax_error?(fee_result)
        invoice.reload

        flag_lifetime_usage_for_refresh
        customer.flag_wallets_for_refresh if grace_period?
        fee_result
      end
      result.non_invoiceable_fees = fee_result.non_invoiceable_fees

      # non-invoiceable fees are created the first time, regardless of grace period.
      # Whenever the invoice is refreshed, the fees are not created again. (see `Fees::ChargeService.already_billed?`)
      # The webhook are sent whenever non-invoiceable fees are found in result.
      result.non_invoiceable_fees&.each do |fee|
        SendWebhookJob.perform_after_commit("fee.created", fee)
      end

      fill_daily_usage

      if tax_error?(fee_result)
        if grace_period?
          SendWebhookJob.perform_after_commit("invoice.drafted", invoice)
          Utils::ActivityLog.produce_after_commit(invoice, "invoice.drafted")
          notify_ready_to_finalize unless invoice.tax_pending?
        end

        return result
      end

      if subscription_gated?
        Invoices::Payments::CreateService.call_async(invoice:)
      elsif grace_period?
        SendWebhookJob.perform_after_commit("invoice.drafted", invoice)
        Utils::ActivityLog.produce_after_commit(invoice, "invoice.drafted")
        notify_ready_to_finalize unless invoice.tax_pending?
      else
        unless invoice.closed? # we dont need to send the webhooks if the invoice was closed ( skip 0 invoice setting )
          SendWebhookJob.perform_after_commit("invoice.created", invoice)
          Utils::ActivityLog.produce_after_commit(invoice, "invoice.created")
          GenerateDocumentsJob.perform_after_commit(invoice:, notify: should_deliver_finalized_email?)
          Integrations::Aggregator::Invoices::CreateJob.perform_after_commit(invoice:) if invoice.should_sync_invoice?
          Integrations::Aggregator::Invoices::Hubspot::CreateJob.perform_after_commit(invoice:) if invoice.should_sync_hubspot_invoice?
          Invoices::Payments::CreateService.call_async(invoice:)
          Utils::SegmentTrack.invoice_created(invoice)
        end
      end

      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    rescue ActiveRecord::RecordNotUnique
      return result if invoicing_reason.to_sym == :subscription_periodic

      raise
    rescue BaseService::ServiceFailure => e
      raise unless e.code.to_s == "duplicated_invoices"
      raise unless invoicing_reason.to_sym == :subscription_periodic

      result
    rescue ActiveRecord::StaleObjectError, Customers::FailedToAcquireLock
      raise
    rescue => e
      result.fail_with_error!(e)
    end

    private

    attr_accessor :subscriptions,
      :timestamp,
      :invoicing_reason,
      :recurring,
      :customer,
      :currency,
      :invoice,
      :skip_charges

    def active_subscriptions
      @active_subscriptions ||= subscriptions.select(&:active?)
    end

    def subscription_gated?
      subscriptions.any?(&:gated?)
    end

    def subscription_payment_gated?
      subscriptions.any?(&:payment_gated?)
    end

    def skip_payment_gating_for_zero_amount
      gated = subscriptions.find(&:payment_gated?)
      Subscriptions::ActivationRules::Payment::EvaluateService.call!(
        rule: gated.activation_rules.payment.sole,
        status: :satisfied
      )
      Subscriptions::ActivationRules::ResolveSubscriptionStatusService.call!(subscription: gated)
    end

    def create_generating_invoice
      invoice_result = Invoices::CreateGeneratingService.call(
        customer:,
        billing_entity: invoice_billing_entity,
        invoice_type: :subscription,
        invoicing_reason:,
        currency:,
        datetime: Time.zone.at(timestamp),
        skip_charges:
      ) do |invoice|
        Invoices::CreateInvoiceSubscriptionService
          .call(invoice:, subscriptions:, timestamp:, invoicing_reason:)
          .raise_if_error!
      end

      invoice_result.raise_if_error!

      @invoice = invoice_result.invoice
    end

    def grace_period?
      return false if subscription_gated?

      @grace_period ||= customer.applicable_invoice_grace_period.positive?
    end

    def invoice_billing_entity
      subscriptions.first&.billing_entity || customer.billing_entity
    end

    def mixed_billing_entities?
      subscriptions.map(&:applicable_billing_entity_id).uniq.many?
    end

    def set_invoice_generated_status
      return invoice.status = :draft if grace_period?

      Invoices::TransitionToFinalStatusService.call(invoice:)
    end

    def should_deliver_finalized_email?
      License.premium? &&
        invoice.billing_entity.email_settings.include?("invoice.finalized")
    end

    def flag_lifetime_usage_for_refresh
      LifetimeUsages::FlagRefreshFromInvoiceService.call(invoice:).raise_if_error!
    end

    def tax_error?(fee_result)
      return false if fee_result.success?

      fee_result.error.is_a?(BaseService::UnknownTaxFailure)
    end

    USAGE_TRACKABLE_REASONS = %i[subscription_periodic subscription_terminating].freeze
    def fill_daily_usage
      return unless invoice.organization.revenue_analytics_enabled?

      subscriptions = invoice
        .invoice_subscriptions
        .select { |is| USAGE_TRACKABLE_REASONS.include?(is.invoicing_reason.to_sym) }
        .map(&:subscription)
      return if subscriptions.blank?

      after_commit do
        DailyUsages::FillFromInvoiceJob.perform_later(invoice:, subscriptions:)
      end
    end

    def notify_ready_to_finalize
      SendWebhookJob.perform_after_commit("invoice.ready_to_finalize", invoice)
      Utils::ActivityLog.produce_after_commit(invoice, "invoice.ready_to_finalize")
    end
  end
end
