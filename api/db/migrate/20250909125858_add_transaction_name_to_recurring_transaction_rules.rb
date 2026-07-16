# frozen_string_literal: true

class AddTransactionNameToRecurringTransactionRules < ActiveRecord::Migration[8.0]
  def change
    add_column :recurring_transaction_rules, :transaction_name, :string, limit: 255
  end
end
