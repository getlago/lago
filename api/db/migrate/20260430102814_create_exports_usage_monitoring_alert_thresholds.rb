# frozen_string_literal: true

class CreateExportsUsageMonitoringAlertThresholds < ActiveRecord::Migration[8.0]
  def change
    create_view :exports_usage_monitoring_alert_thresholds
  end
end
