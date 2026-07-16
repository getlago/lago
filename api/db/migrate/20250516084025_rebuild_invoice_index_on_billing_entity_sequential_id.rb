# frozen_string_literal: true

class RebuildInvoiceIndexOnBillingEntitySequentialId < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    remove_index :invoices,
      [:billing_entity_id, :billing_entity_sequential_id],
      if_exists: true

    add_index :invoices,
      [:billing_entity_id, :billing_entity_sequential_id],
      order: {billing_entity_sequential_id: :desc},
      algorithm: :concurrently,
      include: %i[self_billed],
      if_not_exists: true
  end

  def down
  end
end
