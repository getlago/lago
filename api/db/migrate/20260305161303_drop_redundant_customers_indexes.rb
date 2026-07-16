# frozen_string_literal: true

class DropRedundantCustomersIndexes < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    # Prefix of index_customers_on_organization_id_and_sequential_id
    remove_index :customers, name: :index_customers_on_organization_id, algorithm: :concurrently, if_exists: true
  end
end
