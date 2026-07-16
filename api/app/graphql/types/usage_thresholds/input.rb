# frozen_string_literal: true

module Types
  module UsageThresholds
    class Input < BaseInputObject
      graphql_name "UsageThresholdInput"

      argument :amount_cents, GraphQL::Types::BigInt, required: true
      argument :recurring, Boolean, required: false
      argument :threshold_display_name, String, required: false
    end
  end
end
