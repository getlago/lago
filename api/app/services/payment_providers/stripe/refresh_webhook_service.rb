# frozen_string_literal: true

module PaymentProviders
  module Stripe
    class RefreshWebhookService < BaseService
      Result = BaseResult

      def call
        ::Stripe::WebhookEndpoint.update(
          payment_provider.webhook_id,
          webhook_endpoint_shared_params,
          {api_key:}
        )

        result
      rescue ActiveRecord::RecordInvalid => e
        result.record_validation_failure!(record: e.record)
      rescue ::Stripe::AuthenticationError => e
        deliver_error_webhook(action: "payment_provider.register_webhook", error: e)
        result
      rescue ::Stripe::InvalidRequestError => e
        # Note: Since we're updating an existing endpoint, it shouldn't happen
        raise if e.message != "You have reached the maximum of 16 test webhook endpoints."

        deliver_error_webhook(action: "payment_provider.register_webhook", error: e)
        result
      end
    end
  end
end
