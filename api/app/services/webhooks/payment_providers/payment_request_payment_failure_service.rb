# frozen_string_literal: true

module Webhooks
  module PaymentProviders
    class PaymentRequestPaymentFailureService < Webhooks::BaseService
      private

      def object_serializer
        ::V1::PaymentProviders::PaymentRequestPaymentErrorSerializer.new(
          object,
          root_name: object_type,
          provider_error: options[:provider_error],
          provider_customer_id: options[:provider_customer_id]
        )
      end

      def webhook_type
        "payment_request.payment_failure"
      end

      def object_type
        "payment_provider_payment_request_payment_error"
      end
    end
  end
end
