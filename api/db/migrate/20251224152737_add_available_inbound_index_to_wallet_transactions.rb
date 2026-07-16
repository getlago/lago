# frozen_string_literal: true

class AddAvailableInboundIndexToWalletTransactions < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :wallet_transactions,
      "wallet_id, priority, (CASE WHEN transaction_status = 1 THEN 0 ELSE 1 END), created_at",
      where: "remaining_amount_cents > 0 AND transaction_type = 0 AND status = 1",
      name: "idx_wallet_transactions_available_inbound",
      algorithm: :concurrently
  end
end
