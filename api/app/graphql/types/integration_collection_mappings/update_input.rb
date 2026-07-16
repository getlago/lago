# frozen_string_literal: true

module Types
  module IntegrationCollectionMappings
    class UpdateInput < BaseInput
      graphql_name "UpdateIntegrationCollectionMappingInput"

      argument :id, ID, required: true

      # @deprecated This field is deprecated and will be ignored. Integration ID cannot be updated.
      argument :integration_id, ID, required: false
      # @deprecated This field is deprecated and will be ignored. Mapping type cannot be updated.
      argument :mapping_type, Types::IntegrationCollectionMappings::MappingTypeEnum, required: false
    end
  end
end
