# frozen_string_literal: true

class CreateEventsDeadLetterQueue < ActiveRecord::Migration[8.0]
  def change
    options = <<-SQL
    Kafka()
    SETTINGS
      kafka_broker_list = '#{ENV["LAGO_KAFKA_BOOTSTRAP_SERVERS"]}',
      kafka_topic_list = '#{ENV["LAGO_KAFKA_EVENTS_DEAD_LETTER_TOPIC"]}',
      kafka_group_name = '#{ENV["LAGO_KAFKA_CLICKHOUSE_CONSUMER_GROUP"]}',
      kafka_format = 'JSONEachRow'
    SQL

    create_table :events_dead_letter_queue, id: false, options: do |t|
      t.string :event, null: false
      t.string :initial_error_message, null: false
      t.string :error_code, null: false
      t.string :error_message, null: false
      t.string :failed_at, null: false
    end
  end
end
