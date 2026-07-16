# frozen_string_literal: true

class CreateSecurityLogsQueue < ActiveRecord::Migration[8.0]
  def change
    options = <<-SQL
      Kafka()
      SETTINGS
        kafka_broker_list = '#{ENV["LAGO_KAFKA_BOOTSTRAP_SERVERS"]}',
        kafka_topic_list = '#{ENV["LAGO_KAFKA_SECURITY_LOGS_TOPIC"]}',
        kafka_group_name = '#{ENV["LAGO_KAFKA_CLICKHOUSE_CONSUMER_GROUP"]}',
        kafka_format = 'JSONEachRow'
    SQL

    create_table :security_logs_queue, id: false, options: do |t|
      t.string :organization_id, null: false
      t.string :user_id
      t.string :api_key_id

      t.string :log_id, null: false
      t.string :log_type, null: false
      t.string :log_event, null: false

      t.string :device_info, map: true
      t.string :resources, map: true

      t.datetime :logged_at, null: false, precision: 3
      t.datetime :created_at, null: false, precision: 3
    end
  end
end
