# frozen_string_literal: true

module Types
  module CreditNoteItems
    class Input < Types::BaseInputObject
      graphql_name "CreditNoteItemInput"

      argument :amount_cents, GraphQL::Types::BigInt, required: true
      argument :fee_id, ID, required: true
    end
  end
end
