# frozen_string_literal: true

class AddIndexOnInvoicesOrgSeqId < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :invoices, [:organization_id, :organization_sequential_id],
      order: {organization_sequential_id: :desc},
      algorithm: :concurrently,
      if_not_exists: true,
      include: %i[self_billed]
  end
end
