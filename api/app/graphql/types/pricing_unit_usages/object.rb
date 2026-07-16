# frozen_string_literal: true

module Types
  module PricingUnitUsages
    class Object < Types::BaseObject
      graphql_name "PricingUnitUsage"

      field :id, ID, null: false

      field :amount_cents, GraphQL::Types::BigInt, null: false
      field :conversion_rate, GraphQL::Types::Float, null: false
      field :precise_amount_cents, GraphQL::Types::Float, null: false
      field :precise_unit_amount, GraphQL::Types::Float, null: false
      field :pricing_unit, Types::PricingUnits::Object, null: false
      field :short_name, String, null: false
      field :unit_amount_cents, GraphQL::Types::BigInt, null: false

      field :created_at, GraphQL::Types::ISO8601DateTime, null: false
      field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
    end
  end
end
