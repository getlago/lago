# frozen_string_literal: true

module DatabaseMigrations
  class BackfillChargesCodeJob < ApplicationJob
    queue_as :low_priority
    unique :until_executed

    BATCH_SIZE = 1_000

    def perform(batch_number = 1)
      return Rails.logger.info("Finished populating charge codes") unless Charge.unscoped.where(code: nil).exists?

      result = ActiveRecord::Base.connection.execute(<<-SQL.squish)
        WITH plan_batch AS (
          SELECT DISTINCT plan_id
          FROM charges
          WHERE code IS NULL
          LIMIT #{BATCH_SIZE}
        ),
        ranked_codes AS (
          SELECT
            c.id,
            bm.code AS base_code,
            c.code IS NULL AS needs_update,
            ROW_NUMBER() OVER (
              PARTITION BY c.plan_id, bm.code
              ORDER BY CASE WHEN c.code IS NOT NULL THEN 0 ELSE 1 END, c.created_at, c.id
            ) AS rn
          FROM charges c
          INNER JOIN plan_batch pb ON pb.plan_id = c.plan_id
          INNER JOIN billable_metrics bm ON bm.id = c.billable_metric_id
        )
        UPDATE charges
        SET code = CASE
          WHEN ranked_codes.rn = 1 THEN ranked_codes.base_code
          ELSE ranked_codes.base_code || '_' || ranked_codes.rn
        END
        FROM ranked_codes
        WHERE charges.id = ranked_codes.id
        AND ranked_codes.needs_update = true
      SQL

      if result.cmd_tuples.positive?
        self.class.perform_later(batch_number + 1)
      else
        Rails.logger.info("Finished populating charge codes")
      end
    end

    def lock_key_arguments
      [arguments]
    end
  end
end
