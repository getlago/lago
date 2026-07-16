# frozen_string_literal: true

module Webhooks
  module PaymentProviders
    class CustomerCreatedService < Webhooks::BaseService
      private

      def object_serializer
        ::V1::CustomerSerializer.new(
          object,
          root_name: object_type
        )
      end

      def webhook_type
        "customer.payment_provider_created"
      end

      def object_type
        "customer"
      end
    end
  end
end
