# frozen_string_literal: true

module Integrations
  class CreateService < BaseService
    Result = BaseResult[:integration]

    # Guarantees security logging for integration creation.
    # Subclasses are unaware of the logging — the only requirement
    # is that `result.integration` is set upon the successful `call`.
    module SecurityLogging
      def call(...) # rubocop:disable Lago/ServiceCall
        super.tap { |r| register_security_log(r.integration) if r.success? }
      end
    end

    def self.inherited(subclass)
      super
      subclass.prepend(SecurityLogging)
    end

    private

    def register_security_log(integration)
      Utils::SecurityLog.produce(
        organization: integration.organization,
        log_type: "integration",
        log_event: "integration.created",
        resources: {integration_name: integration.name, integration_type: integration.provider_key}
      )
    end
  end
end
