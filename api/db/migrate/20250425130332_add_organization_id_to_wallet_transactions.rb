# frozen_string_literal: true

class AddOrganizationIdToWalletTransactions < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference :wallet_transactions, :organization, type: :uuid, index: {algorithm: :concurrently}
  end
end
