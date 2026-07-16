# frozen_string_literal: true

class CreateEventsEnrichedExpandedQueue < ActiveRecord::Migration[8.0]
  def change
    options = <<-SQL
          Kafka()
          SETTINGS
            kafka_broker_list = '#{ENV["LAGO_KAFKA_BOOTSTRAP_SERVERS"]}',
            kafka_topic_list = '#{ENV["LAGO_KAFKA_ENRICHED_EVENTS_EXPANDED_TOPIC"]}',
            kafka_group_name = '#{ENV["LAGO_KAFKA_CLICKHOUSE_CONSUMER_GROUP"]}',
            kafka_format = 'JSONEachRow';
    SQL

    create_table :events_enriched_expanded_queue, id: false, options: do |t|
      t.string :organization_id, null: false
      t.string :external_subscription_id, null: false
      t.string :transaction_id, null: false
      t.string :code, null: false
      t.string :aggregation_type
      t.string :subscription_id
      t.string :plan_id
      t.string :properties, null: false
      t.decimal :precise_total_amount_cents, precision: 40, scale: 15
      t.string :value
      t.string :timestamp, null: false
      t.string :charge_id
      t.string :charge_updated_at
      t.string :charge_filter_id
      t.string :charge_filter_updated_at
      t.string :grouped_by
    end
  end
end
