# frozen_string_literal: true

class AddIndexOnExternalIdToCustomer < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!
  def change
    add_index :customers, [:organization_id, :external_id],
      name: "index_customers_on_external_id",
      algorithm: :concurrently,
      using: :btree,
      if_not_exists: true
  end
end
