# frozen_string_literal: true

class AddInvoicesCustomerOrganizationIndex < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :invoices,
      [:customer_id, :organization_id],
      name: :index_invoices_on_organization_id_and_customer_id,
      algorithm: :concurrently,
      if_not_exists: true
  end
end
