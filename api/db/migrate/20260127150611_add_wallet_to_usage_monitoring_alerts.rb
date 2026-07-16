# frozen_string_literal: true

class AddWalletToUsageMonitoringAlerts < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_reference :usage_monitoring_alerts, :wallet, type: :uuid, index: {algorithm: :concurrently}
    add_reference :usage_monitoring_triggered_alerts, :wallet, type: :uuid, index: {algorithm: :concurrently}
  end
end
