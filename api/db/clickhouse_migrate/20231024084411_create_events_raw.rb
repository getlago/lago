# frozen_string_literal: true

class CreateEventsRaw < ActiveRecord::Migration[7.0]
  def change
    options = <<-SQL
      MergeTree
      ORDER BY (organization_id, external_subscription_id, code, transaction_id, timestamp)
    SQL

    create_table :events_raw, id: false, options: do |t|
      t.string :organization_id, null: false
      t.string :external_customer_id, null: false
      t.string :external_subscription_id, null: false
      t.string :transaction_id, null: false
      t.datetime :timestamp, null: false, precision: 3
      t.string :code, null: false
      t.string :properties, map: true, null: false
      t.decimal :precise_total_amount_cents, precision: 40, scale: 15
      t.datetime :ingested_at, null: false, precision: 3
    end
  end
end
