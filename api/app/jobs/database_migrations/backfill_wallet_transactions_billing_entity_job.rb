# frozen_string_literal: true

module DatabaseMigrations
  # Post-release backfill: reads still fall back to the wallet/customer billing entity
  # (Wallet#billing_entity), so this is safe to run whenever and is not an upgrade blocker today.
  # When that fallback is removed, running this becomes mandatory and must be documented as a
  # pre-upgrade step in the bridge-version migration guide.
  class BackfillWalletTransactionsBillingEntityJob < ApplicationJob
    queue_as :low_priority
    unique :until_executed

    BATCH_SIZE = 1_000

    def perform(batch_number = 1)
      result = ActiveRecord::Base.connection.execute(<<~SQL.squish)
        WITH batch AS (
          SELECT wt.id,
                 COALESCE(w.billing_entity_id, c.billing_entity_id) AS resolved_billing_entity_id
          FROM wallet_transactions wt
          JOIN wallets w ON w.id = wt.wallet_id
          JOIN customers c ON c.id = w.customer_id
          WHERE wt.billing_entity_id IS NULL
          LIMIT #{BATCH_SIZE}
        )
        UPDATE wallet_transactions wt
        SET billing_entity_id = batch.resolved_billing_entity_id
        FROM batch
        WHERE wt.id = batch.id
      SQL

      if result.cmd_tuples.positive?
        self.class.perform_later(batch_number + 1)
      else
        Rails.logger.info("Finished backfilling wallet_transactions billing_entity")
      end
    end

    def lock_key_arguments
      [arguments]
    end
  end
end
