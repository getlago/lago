# frozen_string_literal: true

module Webhooks
  module PaymentProviders
    class InvoicePaymentFailureService < Webhooks::BaseService
      private

      def object_serializer
        ::V1::PaymentProviders::InvoicePaymentErrorSerializer.new(
          object,
          root_name: object_type,
          provider_error: options[:provider_error],
          provider_customer_id: options[:provider_customer_id],
          error_details: options[:error_details]
        )
      end

      def webhook_type
        "invoice.payment_failure"
      end

      def object_type
        "payment_provider_invoice_payment_error"
      end
    end
  end
end
