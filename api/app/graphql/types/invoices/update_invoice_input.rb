# frozen_string_literal: true

module Types
  module Invoices
    class UpdateInvoiceInput < BaseInputObject
      description "Update Invoice input arguments"

      argument :id, ID, required: true
      argument :metadata, [Types::Invoices::Metadata::Input], required: false
      argument :payment_status, Types::Invoices::PaymentStatusTypeEnum, required: false
    end
  end
end
