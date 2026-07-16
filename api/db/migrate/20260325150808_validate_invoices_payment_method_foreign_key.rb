# frozen_string_literal: true

class ValidateInvoicesPaymentMethodForeignKey < ActiveRecord::Migration[8.0]
  def change
    validate_foreign_key :invoices, :payment_methods
  end
end
