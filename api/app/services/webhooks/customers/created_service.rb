# frozen_string_literal: true

module Webhooks
  module Customers
    class CreatedService < Webhooks::BaseService
      private

      def object_serializer
        ::V1::CustomerSerializer.new(
          object,
          root_name: "customer",
          includes: %i[integration_customers]
        )
      end

      def webhook_type
        "customer.created"
      end

      def object_type
        "customer"
      end
    end
  end
end
