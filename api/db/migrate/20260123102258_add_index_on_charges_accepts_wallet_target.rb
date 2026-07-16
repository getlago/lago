# frozen_string_literal: true

class AddIndexOnChargesAcceptsWalletTarget < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :charges, :accepts_target_wallet,
      name: "index_charges_on_accepts_target_wallet",
      where: "accepts_target_wallet = true",
      algorithm: :concurrently
  end
end
