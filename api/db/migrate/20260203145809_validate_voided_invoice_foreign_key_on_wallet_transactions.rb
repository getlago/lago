# frozen_string_literal: true

class ValidateVoidedInvoiceForeignKeyOnWalletTransactions < ActiveRecord::Migration[8.0]
  def change
    validate_foreign_key :wallet_transactions, :invoices, column: :voided_invoice_id
  end
end
