# frozen_string_literal: true

class MigrateWalletReadyToBeRefreshed < ActiveRecord::Migration[8.0]
  def up
    safety_assured do
      execute <<~SQL.squish
        UPDATE customers
        SET awaiting_wallet_refresh = TRUE
        FROM wallets
        WHERE wallets.customer_id = customers.id
          AND wallets.ready_to_be_refreshed = TRUE
          AND wallets.status = 0;
      SQL

      execute <<~SQL.squish
        UPDATE wallets
        SET ready_to_be_refreshed = FALSE
        WHERE wallets.ready_to_be_refreshed = TRUE;
      SQL
    end
  end

  def down
    safety_assured do
      execute <<~SQL.squish
        UPDATE wallets
        SET ready_to_be_refreshed = TRUE
        FROM customers
        WHERE wallets.customer_id = customers.id 
          AND customers.awaiting_wallet_refresh = TRUE;
      SQL

      execute <<~SQL.squish
        UPDATE customers
        SET awaiting_wallet_refresh = FALSE
        WHERE customers.awaiting_wallet_refresh = TRUE;
      SQL
    end
  end
end
