# frozen_string_literal: true

module Types
  module Fees
    module AmountDetails
      class GraduatedPercentageRange < Types::BaseObject
        graphql_name "FeeAmountDetailsGraduatedPercentageRange"

        field :flat_unit_amount, String, null: true
        field :from_value, GraphQL::Types::BigInt, null: true
        field :per_unit_total_amount, String, null: true
        field :rate, String, null: true
        field :to_value, GraphQL::Types::BigInt, null: true
        field :total_with_flat_amount, String, null: true
        field :units, String, null: true
      end
    end
  end
end
