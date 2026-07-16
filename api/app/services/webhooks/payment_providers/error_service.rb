# frozen_string_literal: true

module Webhooks
  module PaymentProviders
    class ErrorService < Webhooks::BaseService
      private

      def object_serializer
        ::V1::PaymentProviders::ErrorSerializer.new(
          object,
          root_name: object_type,
          provider_error: options[:provider_error]
        )
      end

      def webhook_type
        "payment_provider.error"
      end

      def object_type
        "payment_provider_error"
      end
    end
  end
end
