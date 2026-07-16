# frozen_string_literal: true

module PaymentProviders
  module Moneyhash
    class BaseService < BaseService
      def initialize(payment_provider)
        @payment_provider = payment_provider

        super
      end

      protected

      attr_reader :payment_provider

      delegate :organization, :organization_id, to: :payment_provider

      def api_key
        payment_provider.api_key
      end

      def deliver_error_webhook(action:, error:)
        SendWebhookJob.perform_later(
          "payment_provider.error",
          payment_provider,
          provider_error: {
            source: "moneyhash",
            action: action,
            message: error.message,
            code: error.code
          }
        )
      end
    end
  end
end
