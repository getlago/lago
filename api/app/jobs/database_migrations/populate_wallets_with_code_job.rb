# frozen_string_literal: true

module DatabaseMigrations
  class PopulateWalletsWithCodeJob < ApplicationJob
    queue_as :low_priority
    unique :until_executed

    # Number of distinct customers to process per batch
    BATCH_SIZE = 1_000

    def perform(batch_number = 1)
      # Check if there are any wallets without code
      return Rails.logger.info("Finished populating wallet codes") unless Wallet.unscoped.where(code: nil).exists?

      # Process in batches by customer_id to maintain uniqueness logic
      # (all wallets for a customer must be processed together)
      result = ActiveRecord::Base.connection.execute(<<-SQL.squish)
        WITH customer_batch AS (
          SELECT DISTINCT customer_id
          FROM wallets
          WHERE code IS NULL
          LIMIT #{BATCH_SIZE}
        ),
        base_codes AS (
          SELECT
            w.id,
            w.customer_id,
            w.created_at,
            CASE
              WHEN w.name IS NULL OR TRIM(w.name) = '' THEN 'default'
              ELSE LOWER(REGEXP_REPLACE(REGEXP_REPLACE(TRIM(w.name), '[^a-zA-Z0-9]+', '_', 'g'), '^_|_$', '', 'g'))
            END as base_code
          FROM wallets w
          INNER JOIN customer_batch cb ON cb.customer_id = w.customer_id
          WHERE w.code IS NULL
        ),
        ranked_codes AS (
          SELECT
            id,
            customer_id,
            created_at,
            base_code,
            ROW_NUMBER() OVER (PARTITION BY customer_id, base_code ORDER BY created_at) as rn
          FROM base_codes
        )
        UPDATE wallets
        SET code = CASE
          WHEN ranked_codes.rn = 1 THEN ranked_codes.base_code
          ELSE ranked_codes.base_code || '_' || EXTRACT(EPOCH FROM ranked_codes.created_at)::bigint::text
        END
        FROM ranked_codes
        WHERE wallets.id = ranked_codes.id
      SQL

      # Queue the next batch if there were updates
      if result.cmd_tuples.positive?
        self.class.perform_later(batch_number + 1)
      else
        Rails.logger.info("Finished populating wallet codes")
      end
    end

    def lock_key_arguments
      [arguments]
    end
  end
end
