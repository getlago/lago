# frozen_string_literal: true

module PaymentProviders
  class DestroyService < BaseService
    def initialize(payment_provider)
      @payment_provider = payment_provider

      super
    end

    def call
      return result.not_found_failure!(resource: "payment_provider") unless payment_provider

      customer_ids = payment_provider.customer_ids

      ActiveRecord::Base.transaction do
        payment_provider.payment_provider_customers.update_all(payment_provider_id: nil) # rubocop:disable Rails/SkipsModelValidations
        payment_provider.discard!

        Customer.where(id: customer_ids).update_all(payment_provider: nil, payment_provider_code: nil) # rubocop:disable Rails/SkipsModelValidations
      end

      # TODO: Create job to unregister webhook

      result.payment_provider = payment_provider
      register_security_log
      result
    end

    private

    attr_reader :payment_provider

    def register_security_log
      Utils::SecurityLog.produce(
        organization: payment_provider.organization,
        log_type: "integration",
        log_event: "integration.deleted",
        resources: {
          integration_name: payment_provider.name,
          integration_type: payment_provider.class.name.demodulize.delete_suffix("Provider").underscore
        }
      )
    end
  end
end
