# frozen_string_literal: true

class AddWalletForeignKeysToUsageMonitoringAlerts < ActiveRecord::Migration[8.0]
  def change
    add_foreign_key :usage_monitoring_alerts, :wallets, validate: false
    add_foreign_key :usage_monitoring_triggered_alerts, :wallets, validate: false
  end
end
