# frozen_string_literal: true

class CreateOrganizationIdAndSequentialIdIndexOnCustomers < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :customers, [:organization_id, :sequential_id],
      name: "index_customers_on_organization_id_and_sequential_id",
      algorithm: :concurrently,
      using: :btree,
      if_not_exists: true
  end
end
