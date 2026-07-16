# frozen_string_literal: true

module IntegrationCustomers
  class UpdateService < BaseService
    def initialize(params:, integration:, integration_customer:)
      @integration_customer = integration_customer
      super(params:, integration:)
    end

    def call
      result = super
      return result if result.error

      return result if integration_customer.type == "IntegrationCustomers::AnrokCustomer"
      return result if integration_customer.type == "IntegrationCustomers::SalesforceCustomer"
      return result.not_found_failure!(resource: "integration_customer") unless integration_customer

      integration_customer.external_customer_id = external_customer_id if external_customer_id.present?
      integration_customer.targeted_object = targeted_object if targeted_object.present?
      integration_customer.save!

      if integration_customer.external_customer_id.present?
        update_result = update_service_class.call(integration:, integration_customer:)
        return update_result unless update_result.success?
      end

      result.integration_customer = integration_customer
      result
    end

    private

    attr_reader :integration_customer

    delegate :customer, to: :integration_customer

    def update_service_class
      @update_service_class ||= if integration_customer.type != "IntegrationCustomers::HubspotCustomer"
        Integrations::Aggregator::Contacts::UpdateService
      elsif integration_customer.targeted_object == "contacts"
        Integrations::Aggregator::Contacts::UpdateService
      else
        Integrations::Aggregator::Companies::UpdateService
      end
    end
  end
end
