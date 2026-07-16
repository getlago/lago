# frozen_string_literal: true

module Types
  module DataApi
    module Usages
      class Object < Types::BaseObject
        graphql_name "DataApiUsage"

        field :amount_cents, GraphQL::Types::BigInt, null: false
        field :amount_currency, Types::CurrencyEnum, null: false
        field :billable_metric_code, String, null: false
        field :units, Float, null: false

        field :is_billable_metric_deleted, Boolean, null: false

        field :end_of_period_dt, GraphQL::Types::ISO8601Date, null: false
        field :start_of_period_dt, GraphQL::Types::ISO8601Date, null: false
      end
    end
  end
end
