# frozen_string_literal: true

module Webhooks
  module PaymentProviders
    class CustomerErrorService < Webhooks::BaseService
      private

      def object_serializer
        ::V1::PaymentProviders::CustomerErrorSerializer.new(
          object,
          root_name: object_type,
          provider_error: options[:provider_error]
        )
      end

      def webhook_type
        "customer.payment_provider_error"
      end

      def object_type
        "payment_provider_customer_error"
      end
    end
  end
end
