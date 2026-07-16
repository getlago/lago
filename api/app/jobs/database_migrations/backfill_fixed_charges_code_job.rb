# frozen_string_literal: true

module DatabaseMigrations
  class BackfillFixedChargesCodeJob < ApplicationJob
    queue_as :low_priority
    unique :until_executed

    BATCH_SIZE = 1_000

    def perform(batch_number = 1)
      return Rails.logger.info("Finished populating fixed charge codes") unless FixedCharge.unscoped.where(code: nil).exists?

      result = ActiveRecord::Base.connection.execute(<<-SQL.squish)
        WITH plan_batch AS (
          SELECT DISTINCT plan_id
          FROM fixed_charges
          WHERE code IS NULL
          LIMIT #{BATCH_SIZE}
        ),
        ranked_codes AS (
          SELECT
            fc.id,
            ao.code AS base_code,
            fc.code IS NULL AS needs_update,
            ROW_NUMBER() OVER (
              PARTITION BY fc.plan_id, ao.code
              ORDER BY CASE WHEN fc.code IS NOT NULL THEN 0 ELSE 1 END, fc.created_at, fc.id
            ) AS rn
          FROM fixed_charges fc
          INNER JOIN plan_batch pb ON pb.plan_id = fc.plan_id
          INNER JOIN add_ons ao ON ao.id = fc.add_on_id
        )
        UPDATE fixed_charges
        SET code = CASE
          WHEN ranked_codes.rn = 1 THEN ranked_codes.base_code
          ELSE ranked_codes.base_code || '_' || ranked_codes.rn
        END
        FROM ranked_codes
        WHERE fixed_charges.id = ranked_codes.id
        AND ranked_codes.needs_update = true
      SQL

      if result.cmd_tuples.positive?
        self.class.perform_later(batch_number + 1)
      else
        Rails.logger.info("Finished populating fixed charge codes")
      end
    end

    def lock_key_arguments
      [arguments]
    end
  end
end
