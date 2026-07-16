# frozen_string_literal: true

module Integrations
  class DestroyService < BaseService
    Result = BaseResult[:integration]

    def initialize(integration:)
      @integration = integration

      super
    end

    def call
      return result.not_found_failure!(resource: "integration") unless integration

      integration.destroy!

      result.integration = integration
      register_security_log(integration)
      result
    end

    private

    attr_reader :integration

    def register_security_log(integration)
      Utils::SecurityLog.produce(
        organization: integration.organization,
        log_type: "integration",
        log_event: "integration.deleted",
        resources: {integration_name: integration.name, integration_type: integration.provider_key}
      )
    end
  end
end
