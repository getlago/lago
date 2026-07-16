# frozen_string_literal: true

module Types
  module AppliedPricingUnits
    class OverrideInput < Types::BaseInputObject
      graphql_name "AppliedPricingUnitOverrideInput"

      argument :conversion_rate, GraphQL::Types::Float, required: true
    end
  end
end
