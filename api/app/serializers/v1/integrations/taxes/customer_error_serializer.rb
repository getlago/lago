# frozen_string_literal: true

module V1
  module Integrations
    module Taxes
      class CustomerErrorSerializer < ModelSerializer
        def serialize
          {
            lago_customer_id: model.id,
            external_customer_id: model.external_id,
            tax_provider: options[:provider],
            tax_provider_code: options[:provider_code],
            provider_error: options[:provider_error]
          }
        end
      end
    end
  end
end
