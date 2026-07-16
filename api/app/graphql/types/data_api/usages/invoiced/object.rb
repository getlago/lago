# frozen_string_literal: true

module Types
  module DataApi
    module Usages
      module Invoiced
        class Object < Types::BaseObject
          graphql_name "DataApiUsageInvoiced"

          field :end_of_period_dt, GraphQL::Types::ISO8601Date, null: false
          field :start_of_period_dt, GraphQL::Types::ISO8601Date, null: false

          field :billable_metric_code, String, null: false

          field :amount_cents, GraphQL::Types::BigInt, null: false
          field :amount_currency, Types::CurrencyEnum, null: false
        end
      end
    end
  end
end
