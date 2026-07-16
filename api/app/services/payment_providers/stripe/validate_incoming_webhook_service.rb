# frozen_string_literal: true

module PaymentProviders
  module Stripe
    class ValidateIncomingWebhookService < BaseService
      def initialize(payload:, signature:, payment_provider:)
        @payload = payload
        @signature = signature
        @provider = payment_provider

        super
      end

      def call
        ::Stripe::Webhook::Signature.verify_header(
          payload,
          signature,
          webhook_secret,
          tolerance: ::Stripe::Webhook::DEFAULT_TOLERANCE
        )

        result
      rescue ::Stripe::SignatureVerificationError
        result.service_failure!(code: "webhook_error", message: "Invalid signature")
      end

      private

      attr_reader :payload, :signature, :provider

      def webhook_secret
        provider.webhook_secret
      end
    end
  end
end
