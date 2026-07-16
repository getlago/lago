# frozen_string_literal: true

module Webhooks
  module Integrations
    class ProviderErrorService < Webhooks::BaseService
      private

      def object_serializer
        ::V1::Integrations::ProviderErrorSerializer.new(
          object,
          root_name: object_type,
          provider_error: options[:provider_error],
          provider: options[:provider],
          provider_code: options[:provider_code]
        )
      end

      def webhook_type
        "integration.provider_error"
      end

      def object_type
        "provider_error"
      end
    end
  end
end
