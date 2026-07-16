# frozen_string_literal: true

class CreateExportsWalletTransactionConsumptions < ActiveRecord::Migration[8.0]
  def change
    create_view :exports_wallet_transaction_consumptions
  end
end
