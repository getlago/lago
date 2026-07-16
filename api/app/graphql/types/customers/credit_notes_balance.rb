# frozen_string_literal: true

module Types
  module Customers
    class CreditNotesBalance < Types::BaseObject
      graphql_name "CustomerCreditNotesBalance"

      field :amount_cents, GraphQL::Types::BigInt, null: false
      field :billing_entity_id, ID, null: false
      field :credits_available_count, Integer, null: false
      field :currency, Types::CurrencyEnum, null: false
    end
  end
end
