# frozen_string_literal: false

class CreateEventsEnrichedMv < ActiveRecord::Migration[7.1]
  def change
    sql = <<~SQL
      SELECT
        organization_id,
        external_subscription_id,
        transaction_id,
        toDateTime64(timestamp, 3) AS timestamp,
        code,
        JSONExtract(properties, 'Map(String, String)') AS properties,
        value,
        precise_total_amount_cents
      FROM events_enriched_queue
    SQL

    create_view :events_enriched_mv, materialized: true, as: sql, to: "events_enriched"
  end
end
