# frozen_string_literal: true

class ValidateXorConstraintsOnUsageMonitoringAlerts < ActiveRecord::Migration[8.0]
  def change
    validate_check_constraint :usage_monitoring_alerts, name: "chk_alerts_subscription_xor_wallet"
    validate_check_constraint :usage_monitoring_triggered_alerts, name: "chk_triggered_alerts_subscription_xor_wallet"
  end
end
