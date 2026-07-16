# frozen_string_literal: true

module Types
  module IntegrationMappings
    class MappableTypeEnum < Types::BaseEnum
      ::IntegrationMappings::BaseMapping::MAPPABLE_TYPES.each do |type|
        value type
      end
    end
  end
end
