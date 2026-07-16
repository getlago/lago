# frozen_string_literal: true

module Types
  module Invoices
    module InvoiceItem
      include Types::BaseInterface

      description "Invoice Item"

      field :id, ID, null: false

      field :amount_cents, GraphQL::Types::BigInt, null: false
      field :amount_currency, Types::CurrencyEnum, null: false

      field :item_code, String, null: false
      field :item_name, String, null: false
      field :item_type, String, null: false
    end
  end
end
