# frozen_string_literal: true

module Types
  module DataApi
    module RevenueStreams
      module Customers
        class Object < Types::BaseObject
          graphql_name "DataApiRevenueStreamCustomer"

          field :customer_deleted_at, GraphQL::Types::ISO8601DateTime, null: true
          field :customer_id, ID, null: false
          field :customer_name, String, null: true
          field :external_customer_id, String, null: false

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
