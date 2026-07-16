# frozen_string_literal: true

module Types
  module Customers
    class OverdueBalance < Types::BaseObject
      graphql_name "CustomerOverdueBalance"

      field :amount_cents, GraphQL::Types::BigInt, null: false
      field :currency, Types::CurrencyEnum, null: false
    end
  end
end
