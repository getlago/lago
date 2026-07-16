# frozen_string_literal: true

module Invoices
  module Payments
    class RetryService < BaseService
      Result = BaseResult[:invoice]

      def initialize(invoice:, payment_method_params: {})
        @invoice = invoice
        @payment_method_params = payment_method_params

        super
      end

      def call
        return result.not_found_failure!(resource: "invoice") if invoice.blank?

        if invoice.draft? || invoice.voided? || invoice.payment_succeeded?
          return result.not_allowed_failure!(code: "invalid_status")
        end

        unless invoice.ready_for_payment_processing?
          return result.not_allowed_failure!(code: "payment_processor_is_currently_handling_payment")
        end

        create_result = Invoices::Payments::CreateService.call_async(invoice:, payment_method_params:)
        deliver_webhook if create_result.payment_provider.nil?

        result.invoice = invoice

        result
      end

      private

      attr_reader :invoice, :payment_method_params

      delegate :customer, to: :invoice

      def deliver_webhook
        SendWebhookJob.perform_later(
          "invoice.payment_failure", invoice, error_details: {code: "customer_must_have_payment_provider"}
        )
      end
    end
  end
end
