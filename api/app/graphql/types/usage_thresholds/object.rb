# frozen_string_literal: true

module Types
  module UsageThresholds
    class Object < Types::BaseObject
      graphql_name "UsageThreshold"

      field :id, ID, null: false

      field :amount_cents, GraphQL::Types::BigInt, null: false
      field :recurring, Boolean, null: false
      field :threshold_display_name, String, null: true
    end
  end
end
