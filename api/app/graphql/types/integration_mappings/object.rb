# frozen_string_literal: true

module Types
  module IntegrationMappings
    class Object < Types::BaseObject
      graphql_name "Mapping"

      field :billing_entity_id, ID, null: true
      field :external_account_code, String, null: true
      field :external_id, String, null: false
      field :external_name, String, null: true
      field :id, ID, null: false
      field :integration_id, ID, null: false
      field :mappable_id, ID, null: false
      field :mappable_type, Types::IntegrationMappings::MappableTypeEnum, null: false
    end
  end
end
