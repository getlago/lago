# frozen_string_literal: true

module IntegrationCustomers
  class HubspotService < ::BaseService
    def initialize(integration:, customer:, subsidiary_id:, **params)
      @customer = customer
      @subsidiary_id = subsidiary_id
      @integration = integration
      @params = params&.with_indifferent_access

      super(nil)
    end

    def create
      create_result = create_service_class.call(
        integration:,
        customer:,
        subsidiary_id: nil
      )

      return create_result if create_result.error

      new_integration_customer = IntegrationCustomers::BaseCustomer.create!(
        organization_id: integration.organization_id,
        integration:,
        customer:,
        external_customer_id: create_result.contact_id,
        email: create_result.email,
        type: "IntegrationCustomers::HubspotCustomer",
        sync_with_provider: true,
        targeted_object:
      )

      result.integration_customer = new_integration_customer
      result
    end

    private

    attr_reader :integration, :customer, :subsidiary_id, :params

    def create_service_class
      @create_service_class ||= if targeted_object == "contacts"
        Integrations::Aggregator::Contacts::CreateService
      else
        Integrations::Aggregator::Companies::CreateService
      end
    end

    def targeted_object
      @targeted_object ||=
        params[:targeted_object].presence ||
        ((customer.customer_type == "individual") ? "contacts" : nil) ||
        ((customer.customer_type == "company") ? "companies" : nil) ||
        integration.default_targeted_object
    end
  end
end
