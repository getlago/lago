# frozen_string_literal: true

class AddPaymentMethodIdAndSkipPspToInvoices < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_column :invoices, :payment_method_id, :uuid
    add_column :invoices, :skip_automatic_payment, :boolean
    add_index :invoices, :payment_method_id, algorithm: :concurrently
  end
end
