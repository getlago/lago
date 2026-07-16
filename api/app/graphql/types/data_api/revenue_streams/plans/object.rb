# frozen_string_literal: true

module Types
  module DataApi
    module RevenueStreams
      module Plans
        class Object < Types::BaseObject
          graphql_name "DataApiRevenueStreamPlan"

          field :plan_code, String, null: false
          field :plan_deleted_at, GraphQL::Types::ISO8601DateTime, null: true
          field :plan_id, ID, null: false
          field :plan_interval, Types::Plans::IntervalEnum, null: false
          field :plan_name, String, null: false

          field :customers_count, Integer, null: false
          field :customers_share, Float, null: false

          field :amount_currency, Types::CurrencyEnum, null: false
          field :gross_revenue_amount_cents, GraphQL::Types::BigInt, null: false
          field :gross_revenue_share, Float, null: true
          field :net_revenue_amount_cents, GraphQL::Types::BigInt, null: false
          field :net_revenue_share, Float, null: true
        end
      end
    end
  end
end
