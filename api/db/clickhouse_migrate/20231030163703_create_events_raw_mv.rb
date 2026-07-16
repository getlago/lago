# frozen_string_literal: false

class CreateEventsRawMv < ActiveRecord::Migration[7.0]
  def change
    sql = <<-SQL
      SELECT
        organization_id,
        external_customer_id,
        external_subscription_id,
        transaction_id,
        toDateTime64(timestamp, 3) as timestamp,
        code,
        JSONExtract(properties, 'Map(String, String)') as properties,
        precise_total_amount_cents,
        ingested_at
      FROM events_raw_queue
    SQL

    create_view :events_raw_mv, materialized: true, as: sql, to: "events_raw"
  end
end
