# frozen_string_literal: true

class CreateUsageMonitoringAlerts < ActiveRecord::Migration[7.2]
  def change
    create_enum :usage_monitoring_alert_types, %w[usage_amount billable_metric_usage_amount]

    create_table :usage_monitoring_alerts, id: :uuid do |t|
      t.references :organization, type: :uuid, foreign_key: true, null: false, index: true
      t.string :subscription_external_id, null: false, index: true
      t.references :billable_metric, type: :uuid, foreign_key: true, null: true, index: true
      t.enum :alert_type, enum_type: "usage_monitoring_alert_types", null: false
      t.numeric :previous_value, precision: 30, scale: 5, null: false, default: 0
      t.datetime :last_processed_at
      t.string :name
      t.string :code, null: false
      t.datetime :deleted_at
      t.timestamps

      t.index %w[subscription_external_id organization_id alert_type],
        unique: true,
        name: "idx_alerts_unique_per_type_per_subscription",
        where: "(billable_metric_id IS NULL AND deleted_at IS NULL)"
      t.index %w[subscription_external_id organization_id alert_type billable_metric_id],
        unique: true,
        name: "idx_alerts_unique_per_type_per_subscription_with_bm",
        where: "(billable_metric_id IS NOT NULL AND deleted_at IS NULL)"
      t.index %w[code subscription_external_id organization_id],
        unique: true,
        name: "idx_alerts_code_unique_per_subscription",
        where: "(deleted_at IS NULL)"
    end

    create_table :usage_monitoring_alert_thresholds, id: :uuid do |t|
      t.references :organization, type: :uuid, foreign_key: true, null: false, index: true
      t.references :usage_monitoring_alert, type: :uuid, foreign_key: true, null: false, index: true
      t.numeric :value, precision: 30, scale: 5, null: false
      t.string :code
      t.boolean :recurring, null: false, default: false
      t.timestamps

      t.index %w[usage_monitoring_alert_id recurring], unique: true, where: "recurring is true"
    end

    create_table :usage_monitoring_triggered_alerts, id: :uuid do |t|
      t.references :organization, type: :uuid, foreign_key: true, null: false, index: true
      t.references :usage_monitoring_alert, type: :uuid, foreign_key: true, null: false, index: true
      t.references :subscription, type: :uuid, foreign_key: true, null: false, index: true

      t.numeric :current_value, precision: 30, scale: 5, null: false
      t.numeric :previous_value, precision: 30, scale: 5, null: false
      t.jsonb :crossed_thresholds, default: {}

      t.datetime :triggered_at, null: false
      t.timestamps
    end
  end
end
