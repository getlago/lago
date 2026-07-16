# frozen_string_literal: true

module Types
  module CreditNoteItems
    class Estimate < Types::BaseObject
      graphql_name "CreditNoteItemEstimate"

      field :amount_cents, GraphQL::Types::BigInt, null: false
      field :fee, Types::Fees::Object, null: false
    end
  end
end
