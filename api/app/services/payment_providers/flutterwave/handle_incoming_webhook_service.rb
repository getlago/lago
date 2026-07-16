# frozen_string_literal: true

module PaymentProviders
  module Flutterwave
    class HandleIncomingWebhookService < BaseService
      Result = BaseResult[:event]
      def initialize(organization_id:, body:, secret:, code: nil)
        @organization_id = organization_id
        @body = body
        @secret = secret
        @code = code

        super
      end

      def call
        payment_provider_result = PaymentProviders::FindService.call(
          organization_id:,
          code:,
          payment_provider_type: "flutterwave"
        )
        return payment_provider_result unless payment_provider_result.success?

        webhook_secret = payment_provider_result.payment_provider.webhook_secret
        return result.service_failure!(code: "webhook_error", message: "Webhook secret is missing") if webhook_secret.blank?

        unless webhook_secret == secret
          return result.service_failure!(code: "webhook_error", message: "Invalid webhook secret")
        end

        PaymentProviders::Flutterwave::HandleEventJob.perform_later(
          organization: payment_provider_result.payment_provider.organization,
          event: body
        )

        result.event = body
        result
      end

      private

      attr_reader :organization_id, :body, :secret, :code
    end
  end
end
