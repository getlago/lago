# frozen_string_literal: true

module Types
  module DataApi
    module Mrrs
      module Plans
        class Object < Types::BaseObject
          graphql_name "DataApiMrrPlan"

          field :amount_currency, Types::CurrencyEnum, null: false
          field :dt, GraphQL::Types::ISO8601Date, null: false

          field :plan_code, String, null: false
          field :plan_deleted_at, GraphQL::Types::ISO8601DateTime, null: true
          field :plan_id, ID, null: false
          field :plan_interval, Types::Plans::IntervalEnum, null: false
          field :plan_name, String, null: false

          field :active_customers_count, GraphQL::Types::BigInt, null: false
          field :active_customers_share, Float, null: false

          field :mrr, Float, null: false
          field :mrr_share, Float, null: true
        end
      end
    end
  end
end
