# frozen_string_literal: true

class SwapInvoicesSequentialUniqueIndex < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :invoices, [:customer_id, :billing_entity_id, :sequential_id],
      unique: true,
      algorithm: :concurrently,
      name: "index_invoices_on_customer_billing_entity_sequential"
    remove_index :invoices, [:customer_id, :sequential_id],
      unique: true,
      algorithm: :concurrently,
      name: "index_invoices_on_customer_id_and_sequential_id"
  end
end
