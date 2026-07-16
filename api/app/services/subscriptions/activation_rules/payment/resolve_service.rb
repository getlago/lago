# frozen_string_literal: true

module Subscriptions
  module ActivationRules
    module Payment
      class ResolveService < BaseService
        Result = BaseResult

        def initialize(subscription:, invoice:, payment_status:)
          @subscription = subscription
          @invoice = invoice
          @payment_status = payment_status.to_sym
          super
        end

        def call
          subscription.with_lock do
            case payment_status
            when :succeeded
              handle_success
            when :failed
              handle_failure
            end
          end

          result
        end

        private

        attr_reader :subscription, :invoice, :payment_status

        def handle_success
          return unless subscription.incomplete? && invoice.open? && invoice.subscription?

          EvaluateService.call!(rule: payment_rule, status: :satisfied)
          Invoices::FinalizeService.call!(invoice:)
          ActivationRules::ResolveSubscriptionStatusService.call!(subscription:)

          after_commit do
            SendWebhookJob.perform_later("invoice.created", invoice)
            Utils::ActivityLog.produce(invoice, "invoice.created")
            Invoices::GenerateDocumentsJob.perform_later(invoice:, notify: should_deliver_email?)
            Integrations::Aggregator::Invoices::CreateJob.perform_later(invoice:) if invoice.should_sync_invoice?
            Integrations::Aggregator::Invoices::Hubspot::CreateJob.perform_later(invoice:) if invoice.should_sync_hubspot_invoice?
            Integrations::Aggregator::Taxes::Invoices::CreateJob.perform_later(invoice:) if invoice.customer.tax_customer
            Utils::SegmentTrack.invoice_created(invoice)

            # The PSP-side payment record carries a placeholder reference set
            # at activation time (the invoice had no number yet). Now that the
            # invoice is finalized and numbered, push the real number back to
            # the PSP so operator dashboards reconcile cleanly. Best-effort.
            PaymentProviders::UpdatePaymentReferenceJob.perform_later(succeeded_payment)
          end
        end

        def handle_failure
          return unless subscription.incomplete? && invoice.open? && invoice.subscription?

          EvaluateService.call!(rule: payment_rule, status: :failed)
          invoice.closed!
          ActivationRules::ResolveSubscriptionStatusService.call!(subscription:)
          subscription.update!(cancellation_reason: :payment_failed)

          after_commit do
            enqueue_recredit_jobs
          end
        end

        def enqueue_recredit_jobs
          invoice.credits.coupon_kind.find_each do |credit|
            AppliedCoupons::RecreditJob.perform_later(credit)
          end

          invoice.credits.credit_note_kind.find_each do |credit|
            CreditNotes::RecreditJob.perform_later(credit)
          end

          invoice.wallet_transactions.outbound.find_each do |wallet_transaction|
            WalletTransactions::RecreditJob.perform_later(wallet_transaction)
          end
        end

        def payment_rule
          @payment_rule ||= subscription.activation_rules.payment.sole
        end

        def succeeded_payment
          @succeeded_payment ||= invoice.payments
            .where(payable_payment_status: :succeeded)
            .order(created_at: :desc)
            .first
        end

        def should_deliver_email?
          License.premium? &&
            invoice.billing_entity.email_settings.include?("invoice.finalized")
        end
      end
    end
  end
end
