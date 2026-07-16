# frozen_string_literal: true

class AddIndexesToWallet < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!
  def change
    add_index :wallets, [:organization_id, :customer_id],
      name: "index_wallets_on_organization_id_and_customer_id",
      algorithm: :concurrently,
      using: :btree,
      if_not_exists: true
  end
end
