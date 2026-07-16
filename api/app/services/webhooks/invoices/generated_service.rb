# frozen_string_literal: true

module Webhooks
  module Invoices
    class GeneratedService < Webhooks::BaseService
      private

      def object_serializer
        ::V1::InvoiceSerializer.new(
          object,
          root_name: "invoice",
          includes: %i[customer]
        )
      end

      def webhook_type
        "invoice.generated"
      end

      def object_type
        "invoice"
      end
    end
  end
end
