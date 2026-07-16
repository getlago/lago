# frozen_string_literal: false

class CreateEventsDeadLetterMv < ActiveRecord::Migration[8.0]
  def change
    sql = <<-SQL
      SELECT
        JSONExtractString(event, 'organization_id') AS organization_id,
        JSONExtractString(event, 'external_subscription_id') AS external_subscription_id,
        JSONExtractString(event, 'code') AS code,
        JSONExtractString(event, 'transaction_id') AS transaction_id,
        toDateTime64(JSONExtractString(event, 'timestamp'), 3) AS timestamp,
        toDateTime64(JSONExtractString(event, 'ingested_at'), 3) AS ingested_at,
        toDateTime64(parseDateTime64BestEffort(failed_at), 3) as failed_at,
        event,
        error_code,
        error_message,
        initial_error_message
      FROM events_dead_letter_queue
    SQL

    create_view :events_dead_letter_mv, materialized: true, as: sql, to: "events_dead_letter", if_not_exists: true
  end
end
