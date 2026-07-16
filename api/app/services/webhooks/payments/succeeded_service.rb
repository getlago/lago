# frozen_string_literal: true

module Webhooks
  module Payments
    class SucceededService < Webhooks::BaseService
      private

      def object_serializer
        ::V1::PaymentSerializer.new(
          object,
          root_name: object_type,
          includes: %i[payment_method]
        )
      end

      def webhook_type
        "payment.succeeded"
      end

      def object_type
        "payment"
      end
    end
  end
end
