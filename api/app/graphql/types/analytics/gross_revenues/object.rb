# frozen_string_literal: true

module Types
  module Analytics
    module GrossRevenues
      class Object < Types::BaseObject
        graphql_name "GrossRevenue"

        field :amount_cents, GraphQL::Types::BigInt, null: true
        field :billing_entity_id, ID, null: true
        field :currency, Types::CurrencyEnum, null: true
        field :invoices_count, GraphQL::Types::BigInt, null: false
        field :month, GraphQL::Types::ISO8601DateTime, null: false
      end
    end
  end
end
