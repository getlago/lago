# frozen_string_literal: true

class ValidateForeignKeyOnRegeneratedInvoiceId < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    validate_foreign_key :invoice_subscriptions, :invoices
  end
end
