# frozen_string_literal: true

class AddIndexOnInvoicesOrganizationIdStatus < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :invoices, [:organization_id, :status],
      name: :idx_invoices_organization_id_status,
      algorithm: :concurrently,
      if_not_exists: true
  end
end
