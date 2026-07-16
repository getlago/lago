# frozen_string_literal: true

class AddAwaitingWalletRefreshToCustomers < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_column :customers, :awaiting_wallet_refresh, :boolean, default: false, null: false
    add_index :customers, :awaiting_wallet_refresh, algorithm: :concurrently
  end
end
