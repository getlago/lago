# frozen_string_literal: true

class AddBillingEntityToWalletTransactions < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_reference :wallet_transactions, :billing_entity, type: :uuid, null: true,
      index: {algorithm: :concurrently}
    add_foreign_key :wallet_transactions, :billing_entities, validate: false
  end
end
