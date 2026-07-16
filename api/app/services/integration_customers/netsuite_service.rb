# frozen_string_literal: true

module IntegrationCustomers
  class NetsuiteService < ::BaseService
    def initialize(integration:, customer:, subsidiary_id:, **params)
      @customer = customer
      @subsidiary_id = subsidiary_id
      @integration = integration
      @params = params&.with_indifferent_access

      super(nil)
    end

    def create
      if existing_integration_customer.present?
        result.integration_customer = existing_integration_customer
        return result
      end

      create_result = Integrations::Aggregator::Contacts::CreateService.call(integration:, customer:, subsidiary_id:)
      return create_result if create_result.error

      new_integration_customer = IntegrationCustomers::BaseCustomer.create!(
        organization_id: integration.organization_id,
        integration:,
        customer:,
        external_customer_id: create_result.contact_id,
        type: "IntegrationCustomers::NetsuiteCustomer",
        subsidiary_id:,
        sync_with_provider: true
      )

      result.integration_customer = new_integration_customer
      result
    end

    private

    attr_reader :integration, :customer, :subsidiary_id, :params

    def existing_integration_customer
      @existing_integration_customer ||= IntegrationCustomers::BaseCustomer.find_by(
        customer:,
        integration:,
        type: "IntegrationCustomers::NetsuiteCustomer"
      )
    end
  end
end
