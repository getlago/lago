# frozen_string_literal: true

class AddUniqueSequentialIdIndexes < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    # Add unique index, then remove the old non-unique one
    add_index :customers, [:organization_id, :sequential_id],
      unique: true,
      where: "sequential_id IS NOT NULL",
      algorithm: :concurrently,
      name: :index_customers_on_org_id_and_sequential_id_unique,
      if_not_exists: true

    remove_index :customers, [:organization_id, :sequential_id],
      name: :index_customers_on_organization_id_and_sequential_id,
      algorithm: :concurrently,
      if_exists: true

    add_index :credit_notes, [:invoice_id, :sequential_id],
      unique: true,
      algorithm: :concurrently,
      name: :index_credit_notes_on_invoice_id_and_sequential_id,
      if_not_exists: true
  end
end
