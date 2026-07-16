# frozen_string_literal: true

class CreateApiLogsQueue < ActiveRecord::Migration[7.0]
  def change
    options = <<-SQL
      Kafka()
      SETTINGS
        kafka_broker_list = '#{ENV["LAGO_KAFKA_BOOTSTRAP_SERVERS"]}',
        kafka_topic_list = '#{ENV["LAGO_KAFKA_API_LOGS_TOPIC"]}',
        kafka_group_name = '#{ENV["LAGO_KAFKA_CLICKHOUSE_CONSUMER_GROUP"]}',
        kafka_format = 'JSONEachRow'
    SQL

    create_table :api_logs_queue, id: false, options: do |t|
      t.string :request_id, null: false
      t.string :organization_id, null: false
      t.string :api_key_id, null: false
      t.string :api_version, null: false

      t.string :client, null: false
      t.string :request_body, null: false, map: true
      t.string :request_response, map: true
      t.string :request_path, null: false
      t.string :request_origin, null: false
      t.enum :http_method, value: {get: 1, post: 2, put: 3, delete: 4}, null: false
      t.integer :http_status, null: false

      t.datetime :logged_at, null: false, precision: 3
      t.datetime :created_at, null: false, precision: 3
    end
  end
end
