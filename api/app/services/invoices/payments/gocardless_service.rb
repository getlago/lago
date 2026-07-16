# frozen_string_literal: true

module Invoices
  module Payments
    class GocardlessService < BaseService
      include Customers::PaymentProviderFinder

      def initialize(invoice = nil)
        @invoice = invoice

        super
      end

      def update_payment_status(provider_payment_id:, status:)
        payment = Payment.find_by(provider_payment_id:)
        return result.not_found_failure!(resource: "gocardless_payment") unless payment

        result.payment = payment
        result.invoice = payment.payable
        return result if payment.payable.payment_succeeded?

        payment.status = status

        payable_payment_status = payment.payment_provider&.determine_payment_status(payment.status)
        payment.payable_payment_status = payable_payment_status
        payment.save!

        deliver_webhook if payable_payment_status.to_sym == :succeeded

        update_invoice_payment_status(payment_status: payable_payment_status)

        result
      rescue ActiveRecord::RecordInvalid => e
        result.record_validation_failure!(record: e.record)
      rescue BaseService::FailedResult => e
        result.fail_with_error!(e)
      end

      private

      attr_accessor :invoice

      delegate :organization, :customer, to: :invoice

      def update_invoice_payment_status(payment_status:, deliver_webhook: true)
        params = {
          payment_status:,
          ready_for_payment_processing: payment_status.to_sym != :succeeded
        }

        if payment_status.to_sym == :succeeded
          total_paid_amount_cents = result.invoice.payments.where(payable_payment_status: :succeeded).sum(:amount_cents)
          params[:total_paid_amount_cents] = total_paid_amount_cents
        end

        update_invoice_result = Invoices::UpdateService.call(
          invoice: result.invoice,
          params:,
          webhook_notification: deliver_webhook
        )
        update_invoice_result.raise_if_error!
      end

      def deliver_webhook
        SendWebhookJob.perform_later("payment.succeeded", result.payment)
      end
    end
  end
end
