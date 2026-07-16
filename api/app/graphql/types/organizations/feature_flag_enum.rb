# frozen_string_literal: true

module Types
  module Organizations
    class FeatureFlagEnum < Types::BaseEnum
      description "Organization Feature Flag Values"

      FeatureFlag::DEFINITION.each_key do |flag|
        value flag
      end
    end
  end
end
