# frozen_string_literal: true

class CreateActivityLogsQueue < ActiveRecord::Migration[7.0]
  def change
    options = <<-SQL
      Kafka()
      SETTINGS
        kafka_broker_list = '#{ENV["LAGO_KAFKA_BOOTSTRAP_SERVERS"]}',
        kafka_topic_list = '#{ENV["LAGO_KAFKA_ACTIVITY_LOGS_TOPIC"]}',
        kafka_group_name = '#{ENV["LAGO_KAFKA_CLICKHOUSE_CONSUMER_GROUP"]}',
        kafka_format = 'JSONEachRow'
    SQL

    create_table :activity_logs_queue, id: false, options: do |t|
      t.string :organization_id, null: false
      t.string :user_id
      t.string :api_key_id

      t.string :external_customer_id
      t.string :external_subscription_id

      t.string :activity_id, null: false
      t.string :activity_type, null: false
      t.enum :activity_source, value: {api: 1, front: 2, system: 3}, null: false
      t.string :activity_object, map: true
      t.string :activity_object_changes, map: true

      t.string :resource_id, null: false
      t.string :resource_type, null: false

      t.datetime :logged_at, null: false, precision: 3
      t.datetime :created_at, null: false, precision: 3
    end
  end
end
