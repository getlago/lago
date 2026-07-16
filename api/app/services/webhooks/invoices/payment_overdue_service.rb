# frozen_string_literal: true

module Webhooks
  module Invoices
    class PaymentOverdueService < Webhooks::BaseService
      private

      def object_serializer
        ::V1::InvoiceSerializer.new(
          object,
          root_name: "invoice",
          includes: %i[customer fees applied_taxes]
        )
      end

      def webhook_type
        "invoice.payment_overdue"
      end

      def object_type
        "invoice"
      end
    end
  end
end
