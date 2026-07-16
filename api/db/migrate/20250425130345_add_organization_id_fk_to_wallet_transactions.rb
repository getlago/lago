# frozen_string_literal: true

class AddOrganizationIdFkToWalletTransactions < ActiveRecord::Migration[7.2]
  def change
    add_foreign_key :wallet_transactions, :organizations, validate: false
  end
end
