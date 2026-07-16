# frozen_string_literal: true

class AddCustomersKeptOrganizationIndex < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :customers,
      :organization_id,
      where: "deleted_at IS NULL",
      name: :index_customers_on_organization_id_kept,
      algorithm: :concurrently,
      if_not_exists: true
  end
end
