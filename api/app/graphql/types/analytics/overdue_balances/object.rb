# frozen_string_literal: true

module Types
  module Analytics
    module OverdueBalances
      class Object < Types::BaseObject
        graphql_name "OverdueBalance"

        field :amount_cents, GraphQL::Types::BigInt, null: false
        field :billing_entity_id, ID, null: true
        field :currency, Types::CurrencyEnum, null: false
        field :lago_invoice_ids, [String], null: false
        field :month, GraphQL::Types::ISO8601DateTime, null: false

        def lago_invoice_ids
          JSON.parse(object["lago_invoice_ids"]).flatten
        end
      end
    end
  end
end
