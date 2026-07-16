# frozen_string_literal: true

module V1
  class IntegrationCustomerSerializer < ModelSerializer
    def serialize
      base_response = {
        lago_id: model.id,
        external_customer_id: model.external_customer_id,
        type:,
        integration_code: model&.integration&.code
      }

      base_response.merge!(model&.settings || {})
    end

    private

    def type
      case model.type
      when "IntegrationCustomers::NetsuiteCustomer"
        "netsuite"
      when "IntegrationCustomers::AnrokCustomer"
        "anrok"
      when "IntegrationCustomers::XeroCustomer"
        "xero"
      when "IntegrationCustomers::HubspotCustomer"
        "hubspot"
      when "IntegrationCustomers::SalesforceCustomer"
        "salesforce"
      end
    end
  end
end
