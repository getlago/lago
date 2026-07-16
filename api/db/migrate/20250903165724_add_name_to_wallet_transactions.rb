# frozen_string_literal: true

class AddNameToWalletTransactions < ActiveRecord::Migration[8.0]
  def change
    add_column :wallet_transactions, :name, :string, limit: 255
  end
end
