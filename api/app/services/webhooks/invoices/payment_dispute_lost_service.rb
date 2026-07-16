# frozen_string_literal: true

module Webhooks
  module Invoices
    class PaymentDisputeLostService < Webhooks::BaseService
      private

      def object_serializer
        ::V1::Invoices::PaymentDisputeLostSerializer.new(
          object,
          root_name: object_type,
          provider_error: options[:provider_error]
        )
      end

      def webhook_type
        "invoice.payment_dispute_lost"
      end

      def object_type
        "payment_dispute_lost"
      end
    end
  end
end
