# frozen_string_literal: true

class AddDirectionToUsageMonitoringAlerts < ActiveRecord::Migration[8.0]
  def change
    create_enum :usage_monitoring_alert_direction, %w[increasing decreasing]

    add_column :usage_monitoring_alerts, :direction, :enum,
      enum_type: :usage_monitoring_alert_direction,
      default: "increasing",
      null: false
  end
end
