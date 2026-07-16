# frozen_string_literal: true

class CreateWalletTransactionConsumptions < ActiveRecord::Migration[8.0]
  def change
    create_table :wallet_transaction_consumptions, id: :uuid do |t|
      t.references :organization,
        foreign_key: true,
        type: :uuid,
        null: false
      t.references :inbound_wallet_transaction,
        foreign_key: {to_table: :wallet_transactions},
        type: :uuid,
        null: false
      t.references :outbound_wallet_transaction,
        foreign_key: {to_table: :wallet_transactions},
        type: :uuid,
        null: false
      t.bigint :consumed_amount_cents, null: false

      t.timestamps
    end

    add_index :wallet_transaction_consumptions,
      [:inbound_wallet_transaction_id, :outbound_wallet_transaction_id],
      unique: true,
      name: "idx_wallet_tx_consumptions_inbound_outbound"
  end
end
