# frozen_string_literal: true

module Types
  module DataApi
    module Mrrs
      class Object < Types::BaseObject
        graphql_name "DataApiMrr"

        field :amount_currency, Types::CurrencyEnum, null: false

        field :ending_mrr, GraphQL::Types::BigInt, null: false
        field :starting_mrr, GraphQL::Types::BigInt, null: false

        field :mrr_change, GraphQL::Types::BigInt, null: false
        field :mrr_churn, GraphQL::Types::BigInt, null: false
        field :mrr_contraction, GraphQL::Types::BigInt, null: false
        field :mrr_expansion, GraphQL::Types::BigInt, null: false
        field :mrr_new, GraphQL::Types::BigInt, null: false

        field :end_of_period_dt, GraphQL::Types::ISO8601Date, null: false
        field :start_of_period_dt, GraphQL::Types::ISO8601Date, null: false
      end
    end
  end
end
