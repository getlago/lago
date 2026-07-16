# frozen_string_literal: true

module Types
  module AppliedPricingUnits
    class Object < Types::BaseObject
      graphql_name "AppliedPricingUnit"

      field :id, ID, null: false

      field :conversion_rate, GraphQL::Types::Float, null: false
      field :pricing_unit, Types::PricingUnits::Object, null: false

      field :created_at, GraphQL::Types::ISO8601DateTime, null: false
      field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
    end
  end
end
