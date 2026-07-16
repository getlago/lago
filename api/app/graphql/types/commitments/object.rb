# frozen_string_literal: true

module Types
  module Commitments
    class Object < Types::BaseObject
      graphql_name "Commitment"

      field :id, ID, null: false

      field :amount_cents, GraphQL::Types::BigInt, null: false
      field :commitment_type, Types::Commitments::CommitmentTypeEnum, null: false
      field :invoice_display_name, String, null: true
      field :plan, Types::Plans::Object, null: false

      field :created_at, GraphQL::Types::ISO8601DateTime, null: false
      field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

      field :taxes, [Types::Taxes::Object], null: true
    end
  end
end
