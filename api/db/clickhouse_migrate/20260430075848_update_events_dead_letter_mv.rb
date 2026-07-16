# frozen_string_literal: true

class UpdateEventsDeadLetterMv < ActiveRecord::Migration[8.0]
  def up
    safety_assured do
      execute <<~SQL
        ALTER TABLE events_dead_letter_mv MODIFY QUERY
        SELECT
          JSONExtractString(event, 'organization_id') AS organization_id,
          JSONExtractString(event, 'external_subscription_id') AS external_subscription_id,
          JSONExtractString(event, 'code') AS code,
          JSONExtractString(event, 'transaction_id') AS transaction_id,
          COALESCE(
            toDateTime64OrNull(JSONExtractString(event, 'timestamp'), 3),
            toDateTime64(
              toFloat64OrNull(JSONExtractString(event, 'timestamp')), 3
            ),
            toDateTime64(JSONExtractString(event, 'ingested_at'), 3)
          ) AS timestamp,
          toDateTime64(JSONExtractString(event, 'ingested_at'), 3) AS ingested_at,
          toDateTime64(parseDateTime64BestEffort(failed_at), 3) as failed_at,
          event,
          error_code,
          error_message,
          initial_error_message
        FROM events_dead_letter_queue;
      SQL
    end
  end
end
