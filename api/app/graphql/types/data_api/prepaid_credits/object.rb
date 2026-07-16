# frozen_string_literal: true

module Types
  module DataApi
    module PrepaidCredits
      class Object < Types::BaseObject
        graphql_name "DataApiPrepaidCredit"

        field :amount_currency, Types::CurrencyEnum, null: false

        field :consumed_amount, Float, null: false
        field :offered_amount, Float, null: false
        field :purchased_amount, Float, null: false
        field :voided_amount, Float, null: false

        field :consumed_credits_quantity, Float, null: false
        field :offered_credits_quantity, Float, null: false
        field :purchased_credits_quantity, Float, null: false
        field :voided_credits_quantity, Float, null: false

        field :end_of_period_dt, GraphQL::Types::ISO8601Date, null: false
        field :start_of_period_dt, GraphQL::Types::ISO8601Date, null: false
      end
    end
  end
end
