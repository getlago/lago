# frozen_string_literal: true

module Types
  module Invoices
    class InvoiceTypeEnum < Types::BaseEnum
      Invoice::INVOICE_TYPES.each do |type|
        value type
      end
    end
  end
end
