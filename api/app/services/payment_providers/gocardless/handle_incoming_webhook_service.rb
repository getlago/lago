# frozen_string_literal: true

module PaymentProviders
  module Gocardless
    class HandleIncomingWebhookService < BaseService
      def initialize(organization_id:, body:, signature:, code: nil)
        @organization_id = organization_id
        @body = body
        @signature = signature
        @code = code

        super
      end

      def call
        payment_provider_result = PaymentProviders::FindService.call(
          organization_id:,
          code:,
          payment_provider_type: "gocardless"
        )
        return payment_provider_result unless payment_provider_result.success?

        result.events = GoCardlessPro::Webhook.parse(
          request_body: body,
          signature_header: signature,
          webhook_endpoint_secret: payment_provider_result.payment_provider&.webhook_secret
        )

        result.events.each do |event|
          PaymentProviders::Gocardless::HandleEventJob.perform_later(
            organization: payment_provider_result.payment_provider.organization,
            payment_provider: payment_provider_result.payment_provider,
            event_json: event.to_json
          )
        end

        result
      rescue JSON::ParserError
        result.service_failure!(code: "webhook_error", message: "Invalid payload")
      rescue GoCardlessPro::Webhook::InvalidSignatureError
        result.service_failure!(code: "webhook_error", message: "Invalid signature")
      end

      private

      attr_reader :organization_id, :body, :signature, :code
    end
  end
end
