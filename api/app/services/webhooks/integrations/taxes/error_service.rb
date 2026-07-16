# frozen_string_literal: true

module Webhooks
  module Integrations
    module Taxes
      class ErrorService < Webhooks::BaseService
        private

        def object_serializer
          ::V1::Integrations::Taxes::CustomerErrorSerializer.new(
            object,
            root_name: object_type,
            provider_error: options[:provider_error],
            provider: options[:provider],
            provider_code: options[:provider_code]
          )
        end

        def webhook_type
          "customer.tax_provider_error"
        end

        def object_type
          "tax_provider_customer_error"
        end
      end
    end
  end
end
