# frozen_string_literal: true

module Types
  module CreditNoteItems
    class Object < Types::BaseObject
      graphql_name "CreditNoteItem"

      field :id, ID, null: false

      field :amount_cents, GraphQL::Types::BigInt, null: false
      field :amount_currency, Types::CurrencyEnum, null: false

      field :created_at, GraphQL::Types::ISO8601DateTime, null: false

      field :fee, Types::Fees::Object, null: false
    end
  end
end
