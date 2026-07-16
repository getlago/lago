# frozen_string_literal: true

module Webhooks
  module Customers
    class ViesCheckService < Webhooks::BaseService
      private

      def current_organization
        @current_organization ||= Organization.find(object.organization_id)
      end

      def object_serializer
        ::V1::CustomerSerializer.new(
          object,
          root_name: "customer",
          includes: %i[vies_check],
          vies_check: options[:vies_check]
        )
      end

      def webhook_type
        "customer.vies_check"
      end

      def object_type
        "customer"
      end
    end
  end
end
