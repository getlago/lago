# frozen_string_literal: true

class AddLastOngoingBalanceSyncAtToWallets < ActiveRecord::Migration[8.0]
  def change
    add_column :wallets, :last_ongoing_balance_sync_at, :timestamp, null: true, default: nil
  end
end
