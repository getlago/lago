# frozen_string_literal: true

class UpdateExportsWalletTransactionsToVersion3 < ActiveRecord::Migration[8.0]
  def change
    update_view :exports_wallet_transactions, version: 3, revert_to_version: 2
  end
end
