# frozen_string_literal: true

module Webhooks
  module Invoices
    class PaymentStatusUpdatedService < Webhooks::BaseService
      private

      def object_serializer
        ::V1::InvoiceSerializer.new(
          object,
          root_name: "invoice",
          includes: %i[customer fees]
        )
      end

      def webhook_type
        "invoice.payment_status_updated"
      end

      def object_type
        "invoice"
      end
    end
  end
end
