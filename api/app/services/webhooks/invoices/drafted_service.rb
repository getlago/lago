# frozen_string_literal: true

module Webhooks
  module Invoices
    class DraftedService < Webhooks::BaseService
      private

      def object_serializer
        ::V1::InvoiceSerializer.new(
          object,
          root_name: "invoice",
          includes: %i[customer subscriptions billing_periods fees credits applied_taxes error_details]
        )
      end

      def webhook_type
        "invoice.drafted"
      end

      def object_type
        "invoice"
      end
    end
  end
end
