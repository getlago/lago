# frozen_string_literal: true

module Types
  module Invoices
    class FeeInput < BaseInputObject
      description "Fee input for creating invoice"

      argument :add_on_id, ID, required: false
      argument :description, String, required: false
      argument :from_datetime, GraphQL::Types::ISO8601DateTime, required: true
      argument :invoice_display_name, String, required: false
      argument :name, String, required: false
      argument :tax_codes, [String], required: false
      argument :to_datetime, GraphQL::Types::ISO8601DateTime, required: true
      argument :unit_amount_cents, GraphQL::Types::BigInt, required: false
      argument :units, GraphQL::Types::Float, required: false
    end
  end
end
