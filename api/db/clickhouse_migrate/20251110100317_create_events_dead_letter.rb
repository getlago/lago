# frozen_string_literal: true

class CreateEventsDeadLetter < ActiveRecord::Migration[8.0]
  def change
    options = <<-SQL
      MergeTree
      ORDER BY (organization_id, external_subscription_id, code, transaction_id, timestamp, ingested_at)
    SQL

    create_table :events_dead_letter, id: false, options: do |t|
      t.string :organization_id, null: false
      t.string :external_subscription_id, null: false
      t.string :code, null: false
      t.string :transaction_id, null: false
      t.datetime :timestamp, null: false, precision: 3
      t.datetime :ingested_at, null: false, precision: 3
      t.datetime :failed_at, null: false, precision: 3
      t.json :event, null: false
      t.string :initial_error_message, null: false
      t.string :error_code, null: false
      t.string :error_message, null: false
    end
  end
end
