# frozen_string_literal: true

module WebhookEndpoints
  class DestroyService < BaseService
    Result = BaseResult[:webhook_endpoint]

    def initialize(webhook_endpoint:)
      @webhook_endpoint = webhook_endpoint

      super
    end

    def call
      return result.not_found_failure!(resource: "webhook_endpoint") unless webhook_endpoint

      webhook_endpoint.destroy!
      track_webhook_endpoint_deleted
      register_security_log

      result.webhook_endpoint = webhook_endpoint
      result
    end

    private

    attr_reader :webhook_endpoint

    def register_security_log
      Utils::SecurityLog.produce(
        organization: webhook_endpoint.organization,
        log_type: "webhook_endpoint",
        log_event: "webhook_endpoint.deleted",
        resources: {webhook_url: webhook_endpoint.webhook_url, signature_algo: webhook_endpoint.signature_algo}
      )
    end

    def track_webhook_endpoint_deleted
      SegmentTrackJob.perform_later(
        membership_id: CurrentContext.membership,
        event: "webhook_endpoint_deleted",
        properties: {
          webhook_endpoint_id: webhook_endpoint.id,
          organization_id: webhook_endpoint.organization_id,
          webhook_url: webhook_endpoint.webhook_url
        }
      )
    end
  end
end
