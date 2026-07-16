# frozen_string_literal: true

module V1
  module PaymentProviders
    class CustomerErrorSerializer < ModelSerializer
      def serialize
        {
          lago_customer_id: model.id,
          external_customer_id: model.external_id,
          payment_provider: model.payment_provider,
          payment_provider_code: model.payment_provider_code,
          provider_error: options[:provider_error]
        }
      end
    end
  end
end
