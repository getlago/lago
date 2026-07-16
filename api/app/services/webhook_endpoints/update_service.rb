# frozen_string_literal: true

module WebhookEndpoints
  class UpdateService < BaseService
    Result = BaseResult[:webhook_endpoint]

    def initialize(id:, organization:, params:)
      @id = id
      @organization = organization
      @params = params

      super
    end

    def call
      webhook_endpoint = organization.webhook_endpoints.find_by(id:)

      return result.not_found_failure!(resource: "webhook_endpoint") if webhook_endpoint.blank?

      webhook_endpoint.webhook_url = params[:webhook_url] if params.key?(:webhook_url)
      webhook_endpoint.signature_algo = params[:signature_algo]&.to_sym if params.key?(:signature_algo)
      webhook_endpoint.name = params[:name] if params.key?(:name)
      webhook_endpoint.event_types = params[:event_types] if params.key?(:event_types)
      webhook_endpoint.save!

      register_security_log(webhook_endpoint)

      result.webhook_endpoint = webhook_endpoint
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_reader :id, :organization, :params

    def register_security_log(webhook_endpoint)
      diff = webhook_endpoint.previous_changes.slice("webhook_url", "signature_algo").to_h
        .transform_keys(&:to_sym)
        .transform_values { |v| {deleted: v[0], added: v[1]}.compact }

      Utils::SecurityLog.produce(
        organization: webhook_endpoint.organization,
        log_type: "webhook_endpoint",
        log_event: "webhook_endpoint.updated",
        resources: {webhook_url: webhook_endpoint.webhook_url, **diff}
      )
    end
  end
end
