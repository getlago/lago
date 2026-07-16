# frozen_string_literal: true

class CreateUsageMonitoringSubscriptionActivities < ActiveRecord::Migration[7.2]
  def change
    create_table :usage_monitoring_subscription_activities, id: :bigserial do |t| # rubocop:disable Rails/CreateTableWithTimestamps
      t.references :organization, type: :uuid, foreign_key: true, null: false, index: true
      t.references :subscription, type: :uuid, foreign_key: true, null: false, index: {
        unique: true, name: :idx_subscription_unique
      }
      t.boolean :enqueued, default: false, null: false
      t.datetime :inserted_at, default: -> { "CURRENT_TIMESTAMP" }, null: false
      t.datetime :enqueued_at

      t.index [:organization_id, :enqueued], name: :idx_enqueued_per_organization
    end
  end
end
