# frozen_string_literal: true

module Types
  module IntegrationCollectionMappings
    class CreateInput < BaseInput
      graphql_name "CreateIntegrationCollectionMappingInput"

      argument :billing_entity_id, ID, required: false
      argument :integration_id, ID, required: true
      argument :mapping_type, Types::IntegrationCollectionMappings::MappingTypeEnum, required: true
    end
  end
end
