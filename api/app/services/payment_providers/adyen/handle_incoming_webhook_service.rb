# frozen_string_literal: true

module PaymentProviders
  module Adyen
    class HandleIncomingWebhookService < BaseService
      def initialize(organization_id:, body:, code: nil)
        @organization_id = organization_id
        @body = body
        @code = code

        super
      end

      def call
        organization = Organization.find_by(id: organization_id)
        return result.service_failure!(code: "webhook_error", message: "Organization not found") unless organization

        payment_provider_result = PaymentProviders::FindService.call(
          organization_id:,
          code:,
          payment_provider_type: "adyen"
        )
        return handle_payment_provider_failure(payment_provider_result) unless payment_provider_result.success?

        validator = ::Adyen::Utils::HmacValidator.new
        hmac_key = payment_provider_result.payment_provider.hmac_key

        if hmac_key && !validator.valid_notification_hmac?(body, hmac_key)
          return result.service_failure!(code: "webhook_error", message: "Invalid signature")
        end

        PaymentProviders::Adyen::HandleEventJob.perform_later(organization:, event_json: body.to_json)

        result.event = body
        result
      end

      private

      attr_reader :organization_id, :body, :code

      def handle_payment_provider_failure(payment_provider_result)
        return payment_provider_result unless payment_provider_result.error.is_a?(BaseService::ServiceFailure)

        result.service_failure!(code: "webhook_error", message: payment_provider_result.error.error_message)
      end
    end
  end
end
