# frozen_string_literal: true

module Webhooks
  module Payments
    class RequiresActionService < Webhooks::BaseService
      private

      def object_serializer
        ::V1::PaymentSerializer.new(
          object,
          root_name: object_type
        )
      end

      def webhook_type
        "payment.requires_action"
      end

      def object_type
        "payment"
      end
    end
  end
end
