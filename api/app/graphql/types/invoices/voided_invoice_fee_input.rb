# frozen_string_literal: true

module Types
  module Invoices
    class VoidedInvoiceFeeInput < BaseInputObject
      description "Fee input for creating or updating invoice from voided invoice"

      argument :add_on_id, ID, required: false
      argument :charge_filter_id, ID, required: false
      argument :charge_id, ID, required: false
      argument :description, String, required: false
      argument :fixed_charge_id, ID, required: false
      argument :id, ID, required: false
      argument :invoice_display_name, String, required: false
      argument :subscription_id, ID, required: false
      argument :unit_amount_cents, GraphQL::Types::BigInt, required: false
      argument :units, GraphQL::Types::Float, required: false
    end
  end
end
