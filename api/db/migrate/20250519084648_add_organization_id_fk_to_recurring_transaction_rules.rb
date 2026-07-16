# frozen_string_literal: true

class AddOrganizationIdFkToRecurringTransactionRules < ActiveRecord::Migration[7.2]
  def change
    add_foreign_key :recurring_transaction_rules, :organizations, validate: false
  end
end
