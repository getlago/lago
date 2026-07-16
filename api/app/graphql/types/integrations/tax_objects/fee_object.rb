# frozen_string_literal: true

module Types
  module Integrations
    module TaxObjects
      class FeeObject < Types::BaseObject
        graphql_name "TaxFeeObject"

        field :amount_cents, GraphQL::Types::BigInt, null: true
        field :item_code, String, null: true
        field :item_id, String, null: true
        field :tax_amount_cents, GraphQL::Types::BigInt, null: true

        field :tax_breakdown, [Types::Integrations::TaxObjects::BreakdownObject]
      end
    end
  end
end
