# frozen_string_literal: true

class FixMetadataInWalletTransactionsAndRecurringRules < ActiveRecord::Migration[7.1]
  def up
    safety_assured do
      execute <<-SQL
        UPDATE wallet_transactions
        SET metadata = '[]'::jsonb
        WHERE metadata = '{}'::jsonb;
      SQL

      execute <<-SQL
        UPDATE recurring_transaction_rules
        SET transaction_metadata = '[]'::jsonb
        WHERE transaction_metadata = '{}'::jsonb;
      SQL
    end
  end

  def down
    safety_assured do
      execute <<-SQL
        UPDATE wallet_transactions
        SET metadata = '{}'::jsonb
        WHERE metadata = '[]'::jsonb;
      SQL

      execute <<-SQL
        UPDATE recurring_transaction_rules
        SET transaction_metadata = '{}'::jsonb
        WHERE transaction_metadata = '[]'::jsonb;
      SQL
    end
  end
end
