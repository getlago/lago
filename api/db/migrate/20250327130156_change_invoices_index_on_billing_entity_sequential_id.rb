# frozen_string_literal: true

class ChangeInvoicesIndexOnBillingEntitySequentialId < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    remove_index :invoices, [:organization_id, :billing_entity_sequential_id],
      order: {billing_entity_sequential_id: :desc},
      algorithm: :concurrently,
      include: %i[self_billed],
      if_exists: true

    add_index :invoices, [:billing_entity_id, :billing_entity_sequential_id],
      order: {billing_entity_sequential_id: :desc},
      algorithm: :concurrently,
      include: %i[self_billed],
      unique: true,
      if_not_exists: true
  end
end
