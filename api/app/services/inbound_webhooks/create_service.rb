# frozen_string_literal: true

module InboundWebhooks
  class CreateService < BaseService
    Result = BaseResult[:inbound_webhook]

    def initialize(organization_id:, webhook_source:, payload:, event_type:, code: nil, signature: nil)
      @organization_id = organization_id
      @webhook_source = webhook_source
      @code = code
      @payload = payload
      @signature = signature
      @event_type = event_type

      super
    end

    def call
      return validate_payload_result unless validate_payload_result.success?

      inbound_webhook = InboundWebhook.create!(
        organization_id:,
        source: webhook_source,
        code:,
        payload:,
        signature:,
        event_type:
      )

      InboundWebhooks::ProcessJob.perform_later(inbound_webhook:)

      result.inbound_webhook = inbound_webhook
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_reader :organization_id, :webhook_source, :code, :payload, :signature, :event_type

    def validate_payload_result
      @validate_payload_result ||= InboundWebhooks::ValidatePayloadService.call(
        organization_id:,
        code:,
        payload:,
        signature:,
        webhook_source:
      )
    end
  end
end
