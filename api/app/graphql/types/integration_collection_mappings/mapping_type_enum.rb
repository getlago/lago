# frozen_string_literal: true

module Types
  module IntegrationCollectionMappings
    class MappingTypeEnum < Types::BaseEnum
      ::IntegrationCollectionMappings::BaseCollectionMapping::MAPPING_TYPES.each do |type|
        value type
      end
    end
  end
end
