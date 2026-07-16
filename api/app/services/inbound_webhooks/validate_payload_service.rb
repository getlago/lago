# frozen_string_literal: true

module InboundWebhooks
  class ValidatePayloadService < BaseService
    WEBHOOK_SOURCES = {
      stripe: PaymentProviders::Stripe::ValidateIncomingWebhookService,
      moneyhash: PaymentProviders::Moneyhash::ValidateIncomingWebhookService
    }

    Result = BaseResult

    def initialize(organization_id:, code:, payload:, webhook_source:, signature:)
      @organization_id = organization_id
      @code = code
      @payload = payload
      @signature = signature
      @webhook_source = webhook_source&.to_sym

      super
    end

    def call
      return result.service_failure!(code: "webhook_error", message: "Invalid webhook source") unless webhook_source_valid?
      return payment_provider_result unless payment_provider_result.success?

      validate_webhook_payload_result
    end

    private

    attr_reader :organization_id, :code, :payload, :signature, :webhook_source

    def webhook_source_valid?
      WEBHOOK_SOURCES.include?(webhook_source)
    end

    def validate_webhook_payload_result
      WEBHOOK_SOURCES[webhook_source].call(
        payload:,
        signature:,
        payment_provider:
      )
    end

    def payment_provider
      payment_provider_result.payment_provider
    end

    def payment_provider_result
      @payment_provider_result ||= PaymentProviders::FindService.call(
        organization_id:,
        code:,
        payment_provider_type: webhook_source.to_s
      )
    end
  end
end
