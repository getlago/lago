# frozen_string_literal: true

class AddIndexesToWalletsCode < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    safety_assured do
      add_index :wallets, [:customer_id, :code],
        unique: true,
        name: "index_uniq_wallet_code_per_customer",
        algorithm: :concurrently
    end
  end

  def down
    safety_assured do
      remove_index :wallets, [:customer_id, :code],
        name: "index_uniq_wallet_code_per_customer",
        algorithm: :concurrently
    end
  end
end
