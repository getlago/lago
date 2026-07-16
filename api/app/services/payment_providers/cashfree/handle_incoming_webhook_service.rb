# frozen_string_literal: true

module PaymentProviders
  module Cashfree
    class HandleIncomingWebhookService < BaseService
      Result = BaseResult[:event]
      def initialize(organization_id:, body:, timestamp:, signature:, code: nil)
        @organization_id = organization_id
        @body = body
        @timestamp = timestamp
        @signature = signature
        @code = code

        super
      end

      def call
        organization = Organization.find_by(id: organization_id)

        payment_provider_result = PaymentProviders::FindService.call(
          organization_id:,
          code:,
          payment_provider_type: "cashfree"
        )

        return payment_provider_result unless payment_provider_result.success?

        secret_key = payment_provider_result.payment_provider.client_secret
        data = "#{timestamp}#{body}"
        gen_signature = Base64.strict_encode64(OpenSSL::HMAC.digest("sha256", secret_key, data))

        unless gen_signature == signature
          return result.service_failure!(code: "webhook_error", message: "Invalid signature")
        end

        PaymentProviders::Cashfree::HandleEventJob.perform_later(organization:, event: body)

        result.event = body
        result
      end

      private

      attr_reader :organization_id, :body, :timestamp, :signature, :code
    end
  end
end
