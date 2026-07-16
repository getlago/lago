# frozen_string_literal: true

class CreateEventsEnrichedExpanded < ActiveRecord::Migration[8.0]
  def change
    options = <<-SQL
        ReplacingMergeTree(timestamp)
        PRIMARY KEY (
          organization_id,
          code,
          external_subscription_id,
          charge_id,
          charge_filter_id,
          toDate(timestamp)
        )
        ORDER BY (
          organization_id,
          code,
          external_subscription_id,
          charge_id,
          charge_filter_id,
          toDate(timestamp),
          timestamp,
          transaction_id
        )
    SQL

    create_table :events_enriched_expanded, id: false, options: do |t|
      t.string :organization_id, null: false
      t.string :external_subscription_id, null: false
      t.string :code, null: false
      t.datetime :timestamp, null: false, precision: 3
      t.string :transaction_id, null: false
      t.json :properties, null: false
      t.string :sorted_properties, map: true, null: false, default: -> { "mapSort(JSONExtract(properties::String, 'Map(String, String)'))" }
      t.string :value
      t.decimal :decimal_value, precision: 38, scale: 26, default: -> { "toDecimal128OrZero(value, 26)" }
      t.datetime :enriched_at, null: false, precision: 3, default: -> { "now()" }
      t.decimal :precise_total_amount_cents, precision: 40, scale: 15
      t.string :subscription_id, null: false, default: -> { "''" }
      t.string :plan_id, null: false, default: -> { "''" }
      t.string :charge_id, null: false, default: -> { "''" }
      t.datetime :charge_version
      t.string :charge_filter_id, null: false, default: -> { "''" }
      t.datetime :charge_filter_version
      t.string :aggregation_type, null: false
      t.json :grouped_by, null: false
      t.string :sorted_grouped_by, map: true, null: false, default: -> { "mapSort(JSONExtract(grouped_by::String, 'Map(String, String)'))" }
    end
  end
end
