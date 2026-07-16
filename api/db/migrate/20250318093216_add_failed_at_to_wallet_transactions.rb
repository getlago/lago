# frozen_string_literal: true

class AddFailedAtToWalletTransactions < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!
  def change
    add_column :wallet_transactions, :failed_at, :datetime
  end
end
