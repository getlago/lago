# frozen_string_literal: true

class ChangeCodeUniquenessOnWallets < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!
  def change
    safety_assured do
      remove_index :wallets, [:customer_id, :code],
        unique: true,
        name: "index_uniq_wallet_code_per_customer",
        algorithm: :concurrently,
        if_exists: true

      add_index :wallets, [:customer_id, :code],
        unique: true,
        where: "status = 0",
        name: "index_uniq_wallet_code_per_customer",
        algorithm: :concurrently,
        if_not_exists: true
    end
  end
end
