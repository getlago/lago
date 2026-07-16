# frozen_string_literal: true

class AddPriorityToWalletTransactions < ActiveRecord::Migration[8.0]
  def change
    add_column :wallet_transactions, :priority, :integer, default: 50, null: false
  end
end
