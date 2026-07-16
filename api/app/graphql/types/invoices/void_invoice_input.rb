# frozen_string_literal: true

module Types
  module Invoices
    class VoidInvoiceInput < Types::BaseInputObject
      description "Void Invoice input arguments"
      argument :id, ID, required: true

      argument :credit_amount, GraphQL::Types::BigInt, required: false
      argument :generate_credit_note, Boolean, required: false
      argument :refund_amount, GraphQL::Types::BigInt, required: false
    end
  end
end
