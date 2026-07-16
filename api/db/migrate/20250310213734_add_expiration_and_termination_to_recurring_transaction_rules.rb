# frozen_string_literal: true

class AddExpirationAndTerminationToRecurringTransactionRules < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    safety_assured do
      change_table :recurring_transaction_rules, bulk: true do |t|
        t.datetime :expiration_at
        t.datetime :terminated_at
        t.integer :status
      end
    end

    safety_assured do
      RecurringTransactionRule.in_batches.update_all(status: 0) # rubocop:disable Rails/SkipsModelValidations
    end

    change_column_default :recurring_transaction_rules, :status, 0

    add_index :recurring_transaction_rules, :expiration_at, algorithm: :concurrently
  end

  def down
    safety_assured do
      remove_index :recurring_transaction_rules, column: :expiration_at
    end

    safety_assured do
      change_table :recurring_transaction_rules, bulk: true do |t|
        t.remove :expiration_at, :terminated_at, :status
      end
    end
  end
end
