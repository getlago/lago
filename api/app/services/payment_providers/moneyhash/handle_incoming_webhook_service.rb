# frozen_string_literal: true

module PaymentProviders
  module Moneyhash
    class HandleIncomingWebhookService < BaseService
      extend Forwardable

      def initialize(inbound_webhook:)
        @inbound_webhook = inbound_webhook

        super
      end

      def call
        organization = Organization.find_by(id: @inbound_webhook.organization_id)
        return result.service_failure!(code: "webhook_error", message: "Organization not found") unless organization

        payment_provider_result = PaymentProviders::FindService.call(
          organization_id: @inbound_webhook.organization_id,
          code: @inbound_webhook.code,
          payment_provider_type: "moneyhash"
        )

        return handle_payment_provider_failure(payment_provider_result) unless payment_provider_result.success?

        PaymentProviders::Moneyhash::HandleEventJob.perform_later(organization:, event_json: @inbound_webhook.payload)
        result.event = @inbound_webhook.payload
        result
      end

      private

      def_delegators :@inbound_webhook, :organization, :payload

      def handle_payment_provider_failure(payment_provider_result)
        return payment_provider_result unless payment_provider_result.error.is_a?(BaseService::ServiceFailure)
        result.service_failure!(code: "webhook_error", message: payment_provider_result.error.error_message)
      end
    end
  end
end
