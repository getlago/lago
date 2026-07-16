# frozen_string_literal: true

module V1
  module PaymentProviders
    class ErrorSerializer < ModelSerializer
      def serialize
        {
          lago_payment_provider_id: model.id,
          payment_provider_code: model.code,
          payment_provider_name: model.name,
          source: options[:provider_error][:source],
          action: options[:provider_error][:action],
          provider_error: options[:provider_error].except(:source, :action)
        }
      end
    end
  end
end
