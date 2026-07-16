# frozen_string_literal: true

class MakeSubscriptionNullableOnUsageMonitoringAlerts < ActiveRecord::Migration[8.0]
  def change
    change_column_null :usage_monitoring_alerts, :subscription_external_id, true
    change_column_null :usage_monitoring_triggered_alerts, :subscription_id, true
  end
end
