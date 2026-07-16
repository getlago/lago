# frozen_string_literal: true

require "openssl"
require "base64"

module PaymentProviders
  module Moneyhash
    class ValidateIncomingWebhookService < BaseService
      def initialize(payload:, signature:, payment_provider:)
        @payload = payload
        @signature = signature
        @provider = payment_provider

        super
      end

      def call
        # extract timestamp and v3_signature from signature
        timestamp, v3_signature = signature.split(",").each_with_object({}) do |part, hash|
          key, value = part.split("=")
          hash[key] = value if %w[t v3].include?(key)
        end.values_at("t", "v3")

        # validate signature
        secret = webhook_secret
        decoded_body = Base64.strict_encode64(payload.to_json)

        to_sign = "#{decoded_body}#{timestamp}"

        calculated_signature = OpenSSL::HMAC.hexdigest("SHA256", secret, to_sign)

        if calculated_signature != v3_signature
          result.service_failure!(code: "webhook_error", message: "Invalid signature")
        end

        result
      end

      private

      attr_reader :payload, :signature, :provider

      def webhook_secret
        provider.signature_key
      end
    end
  end
end
