# frozen_string_literal: true

module Types
  module IntegrationMappings
    class CreateInput < Types::BaseInputObject
      graphql_name "CreateIntegrationMappingInput"

      argument :billing_entity_id, ID, required: false
      argument :external_account_code, String, required: false
      argument :external_id, String, required: true
      argument :external_name, String, required: false
      argument :integration_id, ID, required: true
      argument :mappable_id, ID, required: true
      argument :mappable_type, Types::IntegrationMappings::MappableTypeEnum, required: true
    end
  end
end
