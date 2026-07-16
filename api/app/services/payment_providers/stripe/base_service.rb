# frozen_string_literal: true

module PaymentProviders
  module Stripe
    class BaseService < BaseService
      def initialize(payment_provider)
        @payment_provider = payment_provider

        super
      end

      protected

      attr_reader :payment_provider

      delegate :organization, :organization_id, to: :payment_provider

      def api_key
        payment_provider.secret_key
      end

      def deliver_error_webhook(action:, error:)
        SendWebhookJob.perform_later(
          "payment_provider.error",
          payment_provider,
          provider_error: {
            source: "stripe",
            action: action,
            message: error.message,
            code: error.code
          }
        )
      end

      def webhook_endpoint_shared_params
        {
          url: webhook_endpoint_destination,
          enabled_events: PaymentProviders::StripeProvider::WEBHOOKS_EVENTS
        }
      end

      def webhook_endpoint_destination
        URI.join(
          ENV["LAGO_API_URL"],
          "webhooks/stripe/#{organization_id}?code=#{URI.encode_www_form_component(payment_provider.code)}"
        )
      end
    end
  end
end
