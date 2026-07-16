# frozen_string_literal: true

class AddSubscriptionWithTimestampIndexToInvoiceSubscriptions < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  INDEX_NAME = "idx_invoice_subscriptions_on_subscription_with_timestamps"

  def up
    safety_assured do
      execute <<-SQL
        CREATE INDEX CONCURRENTLY IF NOT EXISTS #{INDEX_NAME}
        ON invoice_subscriptions
        USING btree (
          subscription_id,
          COALESCE(to_datetime, created_at) DESC
        );
      SQL
    end
  end

  def down
    execute <<-SQL
      DROP INDEX CONCURRENTLY IF EXISTS #{INDEX_NAME};
    SQL
  end
end
