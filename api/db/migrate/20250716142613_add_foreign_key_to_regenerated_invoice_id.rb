# frozen_string_literal: true

class AddForeignKeyToRegeneratedInvoiceId < ActiveRecord::Migration[8.0]
  def change
    add_foreign_key :invoice_subscriptions, :invoices,
      column: :regenerated_invoice_id,
      validate: false
  end
end
