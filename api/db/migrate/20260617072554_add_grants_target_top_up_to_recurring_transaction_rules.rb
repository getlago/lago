# frozen_string_literal: true

class AddGrantsTargetTopUpToRecurringTransactionRules < ActiveRecord::Migration[8.0]
  def change
    add_column :recurring_transaction_rules, :grants_target_top_up, :boolean
  end
end
