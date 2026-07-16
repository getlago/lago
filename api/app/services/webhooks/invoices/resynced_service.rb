# frozen_string_literal: true

module Webhooks
  module Invoices
    class ResyncedService < Webhooks::BaseService
      private

      def object_serializer
        ::V1::InvoiceSerializer.new(
          object,
          root_name: "invoice",
          includes: %i[customer billing_periods integration_customers subscriptions fees credits applied_taxes]
        )
      end

      def webhook_type
        "invoice.resynced"
      end

      def object_type
        "invoice"
      end
    end
  end
end
