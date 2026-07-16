# frozen_string_literal: true

class AddWalletMinMaxLimits < ActiveRecord::Migration[8.0]
  def change
    add_column :wallets, :paid_top_up_min_amount_cents, :integer, null: true
    add_column :wallets, :paid_top_up_max_amount_cents, :integer, null: true
    add_column :recurring_transaction_rules, :ignore_paid_top_up_limits, :boolean, default: false, null: false
  end
end
