# frozen_string_literal: true

module Types
  module AppliedPricingUnits
    class Input < Types::BaseInputObject
      graphql_name "AppliedPricingUnitInput"

      argument :code, String, required: true
      argument :conversion_rate, GraphQL::Types::Float, required: true
    end
  end
end
