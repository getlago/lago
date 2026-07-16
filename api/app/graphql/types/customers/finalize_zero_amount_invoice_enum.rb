# frozen_string_literal: true

module Types
  module Customers
    class FinalizeZeroAmountInvoiceEnum < BaseEnum
      Customer::FINALIZE_ZERO_AMOUNT_INVOICE_OPTIONS.each do |type|
        value type
      end
    end
  end
end
