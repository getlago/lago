# frozen_string_literal: true

class CreateExportsUsageMonitoringTriggeredAlerts < ActiveRecord::Migration[8.0]
  def change
    create_view :exports_usage_monitoring_triggered_alerts
  end
end
