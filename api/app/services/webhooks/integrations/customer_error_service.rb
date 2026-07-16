# frozen_string_literal: true

module Webhooks
  module Integrations
    class CustomerErrorService < Webhooks::BaseService
      private

      def object_serializer
        ::V1::Integrations::CustomerErrorSerializer.new(
          object,
          root_name: object_type,
          provider_error: options[:provider_error],
          provider: options[:provider],
          provider_code: options[:provider_code]
        )
      end
    end
  end
end
