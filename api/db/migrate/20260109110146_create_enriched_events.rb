# frozen_string_literal: true

class CreateEnrichedEvents < ActiveRecord::Migration[8.0]
  def up
    safety_assured do
      options = if pg_extension_present?("pg_partman")
        "PARTITION BY RANGE (timestamp)"
      else
        Rails.logger.debug "pg_partman extension is not available on this PostgreSQL server, skipping partitioning"
        ""
      end

      create_table :enriched_events, id: false, primary_key: %i[id timestamp], options: do |t|
        t.uuid :id, null: false, default: -> { "gen_random_uuid()" }
        t.uuid :organization_id, null: false
        t.uuid :event_id, null: false, index: true
        t.string :transaction_id, null: false
        t.string :external_subscription_id, null: false
        t.string :code, null: false
        t.datetime :timestamp, null: false
        t.uuid :subscription_id, null: false
        t.uuid :plan_id, null: false
        t.uuid :charge_id, null: false
        t.uuid :charge_filter_id
        t.jsonb :properties, null: false, default: {}
        t.jsonb :grouped_by, null: false, default: {}
        t.string :value, null: true
        t.decimal :decimal_value, precision: 40, scale: 15, null: false, default: 0.0
        t.datetime :enriched_at, null: false

        t.index %i[organization_id subscription_id charge_id charge_filter_id timestamp], name: "idx_billing_on_enriched_events"
        t.index %i[organization_id external_subscription_id code timestamp], name: "idx_lookup_on_enriched_events"
        t.index %i[organization_id external_subscription_id transaction_id timestamp charge_id], unique: true, name: "idx_unique_on_enriched_events"
      end
    end
  end

  def down
    drop_table :enriched_events
  end
end
