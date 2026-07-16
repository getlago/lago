# frozen_string_literal: true

module Webhooks
  module Integrations
    module Taxes
      class FeeErrorService < Webhooks::BaseService
        private

        def object_serializer
          ::V1::Integrations::Taxes::FeeErrorSerializer.new(
            object,
            root_name: object_type,
            event_transaction_id: options[:event_transaction_id],
            lago_charge_id: options[:lago_charge_id],
            provider_error: options[:provider_error]
          )
        end

        def webhook_type
          "fee.tax_provider_error"
        end

        def object_type
          "tax_provider_fee_error"
        end
      end
    end
  end
end
