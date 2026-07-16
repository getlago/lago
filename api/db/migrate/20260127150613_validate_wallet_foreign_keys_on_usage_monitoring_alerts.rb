# frozen_string_literal: true

class ValidateWalletForeignKeysOnUsageMonitoringAlerts < ActiveRecord::Migration[8.0]
  def change
    validate_foreign_key :usage_monitoring_alerts, :wallets
    validate_foreign_key :usage_monitoring_triggered_alerts, :wallets
  end
end
