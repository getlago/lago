# frozen_string_literal: true

module IntegrationCustomers
  class AvalaraService < ::BaseService
    Result = BaseResult[:integration_customer]

    def initialize(integration:, customer:, subsidiary_id:, **params)
      @customer = customer
      @subsidiary_id = subsidiary_id
      @integration = integration
      @params = params&.with_indifferent_access

      super(nil)
    end

    def create
      create_result = Integrations::Aggregator::Contacts::CreateService.call(
        integration:,
        customer:,
        subsidiary_id: nil
      )

      return create_result if create_result.error || create_result.contact_id.nil?

      new_integration_customer = IntegrationCustomers::BaseCustomer.create!(
        organization_id: integration.organization_id,
        integration:,
        customer:,
        external_customer_id: create_result.contact_id,
        type: "IntegrationCustomers::AvalaraCustomer",
        sync_with_provider: true
      )

      result.integration_customer = new_integration_customer
      result
    end

    private

    attr_reader :integration, :customer, :subsidiary_id, :params
  end
end
