# frozen_string_literal: true

module WebhookEndpoints
  class CreateService < BaseService
    Result = BaseResult[:webhook_endpoint]

    def initialize(organization:, params:)
      @organization = organization
      @params = params

      super
    end

    def call
      webhook_endpoint = organization.webhook_endpoints.new(
        webhook_url: params[:webhook_url],
        signature_algo: params[:signature_algo]&.to_sym || :jwt,
        name: params[:name],
        event_types: params[:event_types]
      )

      webhook_endpoint.save!

      result.webhook_endpoint = webhook_endpoint
      track_webhook_webdpoint_created(result.webhook_endpoint)
      register_security_log(webhook_endpoint)
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_reader :organization, :params

    def register_security_log(webhook_endpoint)
      Utils::SecurityLog.produce(
        organization: organization,
        log_type: "webhook_endpoint",
        log_event: "webhook_endpoint.created",
        resources: {webhook_url: webhook_endpoint.webhook_url, signature_algo: webhook_endpoint.signature_algo}
      )
    end

    def track_webhook_webdpoint_created(webhook_endpoint)
      SegmentTrackJob.perform_later(
        membership_id: CurrentContext.membership,
        event: "webhook_endpoint_created",
        properties: {
          webhook_endpoint_id: webhook_endpoint.id,
          organization_id: webhook_endpoint.organization_id,
          webhook_url: webhook_endpoint.webhook_url
        }
      )
    end
  end
end
