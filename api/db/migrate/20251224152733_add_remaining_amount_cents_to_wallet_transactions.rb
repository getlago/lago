# frozen_string_literal: true

class AddRemainingAmountCentsToWalletTransactions < ActiveRecord::Migration[8.0]
  def change
    add_column :wallet_transactions, :remaining_amount_cents, :bigint

    add_check_constraint :wallet_transactions,
      "remaining_amount_cents >= 0 OR remaining_amount_cents IS NULL",
      name: "remaining_amount_cents_non_negative",
      validate: false
  end
end
