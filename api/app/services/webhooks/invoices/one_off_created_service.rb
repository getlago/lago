# frozen_string_literal: true

module Webhooks
  module Invoices
    class OneOffCreatedService < Webhooks::BaseService
      private

      def object_serializer
        ::V1::InvoiceSerializer.new(
          object,
          root_name: "invoice",
          includes: %i[customer fees applied_taxes applied_invoice_custom_sections]
        )
      end

      def webhook_type
        "invoice.one_off_created"
      end

      def object_type
        "invoice"
      end
    end
  end
end
