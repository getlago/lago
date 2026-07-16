# frozen_string_literal: true

module InboundWebhooks
  class ProcessService < BaseService
    WEBHOOK_HANDLER_SERVICES = {
      stripe: PaymentProviders::Stripe::HandleIncomingWebhookService,
      moneyhash: PaymentProviders::Moneyhash::HandleIncomingWebhookService
    }

    Result = BaseResult[:inbound_webhook]

    def initialize(inbound_webhook:)
      @inbound_webhook = inbound_webhook

      super
    end

    def call
      return result if within_processing_window?
      return result if inbound_webhook.failed?
      return result if inbound_webhook.succeeded?

      inbound_webhook.processing!

      handler_result = handler_service_klass.call(inbound_webhook:)

      unless handler_result.success?
        inbound_webhook.failed!
        return handler_result
      end

      inbound_webhook.succeeded!

      result.inbound_webhook = inbound_webhook
      result
    rescue
      inbound_webhook.failed!
      raise
    end

    private

    attr_reader :inbound_webhook

    def handler_service_klass
      WEBHOOK_HANDLER_SERVICES.fetch(webhook_source) do
        raise NameError, "Invalid inbound webhook source: #{webhook_source}"
      end
    end

    def webhook_source
      inbound_webhook.source.to_sym
    end

    def within_processing_window?
      inbound_webhook.processing? && inbound_webhook.processing_at > InboundWebhook::WEBHOOK_PROCESSING_WINDOW.ago
    end
  end
end
