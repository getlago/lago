# frozen_string_literal: true

module Types
  module DataApi
    module Usages
      module Forecasted
        class Object < Types::BaseObject
          graphql_name "DataApiUsageForecasted"

          field :amount_cents, GraphQL::Types::BigInt, null: false
          field :amount_cents_forecast_conservative, GraphQL::Types::BigInt, null: false
          field :amount_cents_forecast_optimistic, GraphQL::Types::BigInt, null: false
          field :amount_cents_forecast_realistic, GraphQL::Types::BigInt, null: false
          field :amount_currency, Types::CurrencyEnum, null: false

          field :units, Float, null: false
          field :units_forecast_conservative, Float, null: false
          field :units_forecast_optimistic, Float, null: false
          field :units_forecast_realistic, Float, null: false

          field :end_of_period_dt, GraphQL::Types::ISO8601Date, null: false
          field :start_of_period_dt, GraphQL::Types::ISO8601Date, null: false
        end
      end
    end
  end
end
