# frozen_string_literal: true

class CreateActivityLogs < ActiveRecord::Migration[7.1]
  def change
    options = <<-SQL
      ReplacingMergeTree(logged_at)
      PRIMARY KEY (organization_id, activity_id, logged_at)
      ORDER BY (organization_id, activity_id, logged_at)
    SQL

    create_table :activity_logs, id: false, options: do |t|
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
