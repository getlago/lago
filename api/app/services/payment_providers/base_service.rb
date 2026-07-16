# frozen_string_literal: true

module PaymentProviders
  class BaseService < BaseService
    # Guarantees security logging for payment provider creation and updates.
    # Subclasses are unaware of the logging — the only requirement
    # is that `result.{type}_provider` is set upon the successful `create_or_update`.
    #
    # TODO: Once payment provider services migrate to the standard `call` pattern,
    #       this can be refactored into a `BaseService` around-middleware.
    module SecurityLogging
      def create_or_update(...)
        super.tap { |r| register_security_log(extract_provider(r)) if r.success? }
      end
    end

    def self.inherited(subclass)
      super
      subclass.prepend(SecurityLogging)
    end

    private

    def payment_provider_code_changed?(payment_provider, old_code, args)
      payment_provider.persisted? && args.key?(:code) && old_code != args[:code]
    end

    def integration_type
      self.class.name.demodulize.delete_suffix("Service").underscore
    end

    def extract_provider(result)
      result.send("#{integration_type}_provider")
    end

    def register_security_log(provider)
      event = provider.previous_changes.key?("id") ? "created" : "updated"

      resources = {integration_name: provider.name, integration_type:}

      if event == "updated"
        diff = provider.previous_changes.except("updated_at", "secrets")
          .to_h.transform_keys(&:to_sym)
          .transform_values { |v| {deleted: v[0], added: v[1]}.compact }
        resources.merge!(diff)
      end

      Utils::SecurityLog.produce(
        organization: provider.organization,
        log_type: "integration",
        log_event: "integration.#{event}",
        resources:
      )
    end
  end
end
