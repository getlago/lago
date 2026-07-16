# frozen_string_literal: true

module Types
  module AddOns
    class UpdateInput < Types::BaseInputObject
      graphql_name "UpdateAddOnInput"

      argument :amount_cents, GraphQL::Types::BigInt, required: true
      argument :amount_currency, Types::CurrencyEnum, required: true
      argument :code, String, required: true
      argument :description, String, required: false
      argument :id, ID, required: true
      argument :invoice_display_name, String, required: false
      argument :name, String, required: true
      argument :tax_codes, [String], required: false
    end
  end
end
