# frozen_string_literal: true

module Webhooks
  module PaymentProviders
    class CustomerCheckoutService < Webhooks::BaseService
      private

      def object_serializer
        ::V1::PaymentProviders::CustomerCheckoutSerializer.new(
          object,
          root_name: object_type,
          checkout_url: options[:checkout_url]
        )
      end

      def webhook_type
        "customer.checkout_url_generated"
      end

      def object_type
        "payment_provider_customer_checkout_url"
      end
    end
  end
end
