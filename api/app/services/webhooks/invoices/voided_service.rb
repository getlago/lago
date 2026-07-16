# frozen_string_literal: true

module Webhooks
  module Invoices
    class VoidedService < Webhooks::BaseService
      private

      def object_serializer
        ::V1::InvoiceSerializer.new(
          object,
          root_name: "invoice",
          includes: %i[customer billing_periods subscriptions fees credits applied_taxes]
        )
      end

      def webhook_type
        "invoice.voided"
      end

      def object_type
        "invoice"
      end
    end
  end
end
