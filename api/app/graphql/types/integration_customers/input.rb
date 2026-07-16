# frozen_string_literal: true

module Types
  module IntegrationCustomers
    class Input < Types::BaseInputObject
      graphql_name "IntegrationCustomerInput"

      argument :id, ID, required: false

      argument :external_customer_id, String, required: false
      argument :integration_code, String, required: false
      argument :integration_id, ID, required: false
      argument :integration_type, Types::Integrations::IntegrationTypeEnum, required: false
      argument :subsidiary_id, String, required: false
      argument :sync_with_provider, Boolean, required: false
      argument :targeted_object, Types::Integrations::Hubspot::TargetedObjectsEnum, required: false
    end
  end
end
