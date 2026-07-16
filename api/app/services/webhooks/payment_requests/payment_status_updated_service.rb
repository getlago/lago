# frozen_string_literal: true

module Webhooks
  module PaymentRequests
    class PaymentStatusUpdatedService < Webhooks::BaseService
      private

      def object_serializer
        ::V1::PaymentRequestSerializer.new(
          object,
          root_name: "payment_request",
          includes: %i[customer invoices]
        )
      end

      def webhook_type
        "payment_request.payment_status_updated"
      end

      def object_type
        "payment_request"
      end
    end
  end
end
