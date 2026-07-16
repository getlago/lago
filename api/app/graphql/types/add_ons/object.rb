# frozen_string_literal: true

module Types
  module AddOns
    class Object < Types::BaseObject
      graphql_name "AddOn"

      field :id, ID, null: false
      field :organization, Types::Organizations::OrganizationType

      field :code, String, null: false
      field :description, String, null: true
      field :invoice_display_name, String, null: true
      field :name, String, null: false

      field :amount_cents, GraphQL::Types::BigInt, null: false
      field :amount_currency, Types::CurrencyEnum, null: false

      field :created_at, GraphQL::Types::ISO8601DateTime, null: false
      field :deleted_at, GraphQL::Types::ISO8601DateTime, null: true
      field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

      field :applied_add_ons_count, Integer, null: false
      field :customers_count, Integer, null: false, description: "Number of customers using this add-on"

      field :taxes, [Types::Taxes::Object]

      field :integration_mappings, [Types::IntegrationMappings::Object], null: true do
        argument :integration_id, ID, required: false
      end

      def customers_count
        object.applied_add_ons.select(:customer_id).distinct.count
      end

      def applied_add_ons_count
        object.applied_add_ons.count
      end

      def integration_mappings(integration_id: nil)
        mappings = object.integration_mappings
        mappings = mappings.where(integration_id:) if integration_id
        mappings
      end
    end
  end
end
