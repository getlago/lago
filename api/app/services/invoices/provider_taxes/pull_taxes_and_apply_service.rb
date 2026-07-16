# frozen_string_literal: true

module Invoices
  module ProviderTaxes
    class PullTaxesAndApplyService < BaseService
      Result = BaseResult[:invoice]

      def initialize(invoice:)
        @invoice = invoice

        super
      end

      def call
        return result.not_found_failure!(resource: "invoice") unless invoice
        return result.not_found_failure!(resource: "integration_customer") unless customer.tax_customer
        return result unless invoice.pending? || invoice.draft? || invoice.subscription_gated?
        return result unless invoice.tax_pending?

        invoice.error_details.tax_error.discard_all # rubocop:disable Lago/DiscardAll
        taxes_result = if invoice.draft? || invoice.subscription_gated?
          Integrations::Aggregator::Taxes::Invoices::CreateDraftService.call(invoice:, fees: invoice.fees)
        else
          Integrations::Aggregator::Taxes::Invoices::CreateService.call(invoice:, fees: invoice.fees)
        end

        unless taxes_result.success?
          create_error_detail(taxes_result.error)
          invoice.tax_status = "failed"
          invoice.status = "failed" unless invoice.draft?
          invoice.save!

          notify_ready_to_finalize
          return result
        end

        provider_taxes = taxes_result.fees

        ActiveRecord::Base.transaction do
          invoice.reload
          return result if invoice.finalized? || invoice.voided? || invoice.closed?

          unless invoice.draft?
            invoice.issuing_date = issuing_date
            invoice.payment_due_date = payment_due_date
          end

          Invoices::ComputeAmountsFromFees.call(invoice:, provider_taxes:)

          create_credit_note_credit if should_create_credit_note_credit?
          create_applied_prepaid_credit if should_create_applied_prepaid_credit?

          invoice.payment_status = invoice.total_amount_cents.positive? ? :pending : :succeeded
          invoice.tax_status = "succeeded"

          skip_payment_gating_for_zero_amount if invoice.subscription_payment_gated? && invoice.total_amount_cents.zero?

          Invoices::TransitionToFinalStatusService.call(invoice:) unless invoice.draft?

          invoice.save!
          invoice.reload

          result.invoice = invoice
        end

        if invoice.subscription_gated?
          Invoices::Payments::CreateService.call_async(invoice:)
        elsif invoice.finalized?
          SendWebhookJob.perform_later("invoice.created", invoice)
          Utils::ActivityLog.produce(invoice, "invoice.created")
          GenerateDocumentsJob.perform_later(invoice:, notify: should_deliver_email?)
          Integrations::Aggregator::Invoices::CreateJob.perform_later(invoice:) if invoice.should_sync_invoice?
          Integrations::Aggregator::Invoices::Hubspot::CreateJob.perform_later(invoice:) if invoice.should_sync_hubspot_invoice?
          Invoices::Payments::CreateService.call_async(invoice:)
          Utils::SegmentTrack.invoice_created(invoice)
        elsif invoice.draft?
          notify_ready_to_finalize
        end

        result
      rescue ActiveRecord::RecordInvalid => e
        result.record_validation_failure!(record: e.record)
      rescue ActiveRecord::InvalidForeignKey
        # NOTE: A draft invoice has been refreshed while the taxes were applied
        raise unless invoice.draft?
        result
      rescue BaseService::FailedResult => e
        e.result
      end

      private

      attr_accessor :invoice

      def notify_ready_to_finalize
        return unless invoice.draft?
        SendWebhookJob.perform_later("invoice.ready_to_finalize", invoice)
        Utils::ActivityLog.produce(invoice, "invoice.ready_to_finalize")
      end

      def skip_payment_gating_for_zero_amount
        gated = invoice.subscriptions.find(&:payment_gated?)
        return unless gated

        Subscriptions::ActivationRules::Payment::EvaluateService.call!(
          rule: gated.activation_rules.payment.sole,
          status: :satisfied
        )
        Subscriptions::ActivationRules::ResolveSubscriptionStatusService.call!(subscription: gated)
      end

      def should_deliver_email?
        License.premium? &&
          invoice.billing_entity.email_settings.include?("invoice.finalized")
      end

      def should_create_credit_note_credit?
        return false if invoice.draft?

        !invoice.one_off?
      end

      def should_create_applied_prepaid_credit?
        return false if invoice.draft?
        return false if invoice.one_off?

        invoice.total_amount_cents&.positive?
      end

      def create_credit_note_credit
        credit_result = Credits::CreditNoteService.new(invoice:).call
        credit_result.raise_if_error!

        invoice.total_amount_cents -= credit_result.credits.sum(&:amount_cents) if credit_result.credits
      end

      def create_applied_prepaid_credit
        prepaid_credit_result = Credits::AppliedPrepaidCreditsService.call!(invoice:)
        invoice.total_amount_cents -= prepaid_credit_result.prepaid_credit_amount_cents
      end

      def issuing_date
        @issuing_date ||=
          if issuing_date_keep_anchor?
            invoice.issuing_date
          else
            Time.current.in_time_zone(customer.applicable_timezone).to_date
          end
      end

      def issuing_date_keep_anchor?
        invoice.invoice_subscriptions.first&.recurring? &&
          customer.applicable_subscription_invoice_issuing_date_adjustment == "keep_anchor"
      end

      def payment_due_date
        @payment_due_date ||= issuing_date + customer.applicable_net_payment_term.days
      end

      def customer
        @customer ||= invoice.customer
      end

      def create_error_detail(error)
        error_result = ErrorDetails::CreateService.call(
          owner: invoice,
          organization: invoice.organization,
          params: {
            error_code: :tax_error,
            details: {
              tax_error: error.code
            }.tap do |details|
              details[:tax_error_message] = error.error_message if error.error_message.present?
            end
          }
        )
        error_result.raise_if_error!
      end
    end
  end
end
