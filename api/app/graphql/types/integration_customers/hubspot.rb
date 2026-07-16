# frozen_string_literal: true

module Types
  module IntegrationCustomers
    class Hubspot < Types::BaseObject
      graphql_name "HubspotCustomer"

      field :external_customer_id, String, null: true
      field :id, ID, null: false
      field :integration_code, String, null: true
      field :integration_id, ID, null: true
      field :integration_type, Types::Integrations::IntegrationTypeEnum, null: true
      field :sync_with_provider, Boolean, null: true
      field :targeted_object, Types::Integrations::Hubspot::TargetedObjectsEnum, null: true

      def integration_type
        object.integration&.type
        case object.integration&.type
        when "Integrations::HubspotIntegration"
          "hubspot"
        end
      end

      def integration_code
        object.integration&.code
      end
    end
  end
end
