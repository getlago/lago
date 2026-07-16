# frozen_string_literal: true

class ChangeWalletMinMaxToBigInt < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    safety_assured do
      remove_column :wallets, :paid_top_up_min_amount_cents, :integer
      remove_column :wallets, :paid_top_up_max_amount_cents, :integer
    end

    add_column :wallets, :paid_top_up_min_amount_cents, :bigint, null: true
    add_column :wallets, :paid_top_up_max_amount_cents, :bigint, null: true
  end
end
