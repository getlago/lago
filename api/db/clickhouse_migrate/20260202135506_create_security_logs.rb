# frozen_string_literal: true

class CreateSecurityLogs < ActiveRecord::Migration[8.0]
  def change
    options = <<-SQL
      ReplacingMergeTree(logged_at)
      PRIMARY KEY (organization_id, log_id, logged_at)
      ORDER BY (organization_id, log_id, logged_at)
    SQL

    create_table :security_logs, id: false, options: do |t|
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
