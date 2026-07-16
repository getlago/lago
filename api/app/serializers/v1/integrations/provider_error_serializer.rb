# frozen_string_literal: true

module V1
  module Integrations
    class ProviderErrorSerializer < ModelSerializer
      def serialize
        {
          lago_integration_id: model.id,
          provider: options[:provider],
          provider_code: options[:provider_code],
          provider_error: options[:provider_error]
        }
      end
    end
  end
end
