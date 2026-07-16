# frozen_string_literal: true

class AddVoidedInvoiceForeignKeyToWalletTransactions < ActiveRecord::Migration[8.0]
  def change
    add_foreign_key :wallet_transactions, :invoices, column: :voided_invoice_id, validate: false
  end
end
