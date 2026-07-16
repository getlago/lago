# frozen_string_literal: true

module Types
  module Commitments
    class Input < Types::BaseInputObject
      graphql_name "CommitmentInput"

      argument :amount_cents, GraphQL::Types::BigInt, required: false
      argument :commitment_type, Types::Commitments::CommitmentTypeEnum, required: false
      argument :id, ID, required: false
      argument :invoice_display_name, String, required: false
      argument :tax_codes, [String], required: false
    end
  end
end
