# frozen_string_literal: true

class AddXorConstraintsAndWalletIndexesToUsageMonitoringAlerts < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_check_constraint :usage_monitoring_alerts,
      "(subscription_external_id IS NOT NULL) <> (wallet_id IS NOT NULL)",
      name: "chk_alerts_subscription_xor_wallet",
      validate: false

    add_check_constraint :usage_monitoring_triggered_alerts,
      "(subscription_id IS NOT NULL) <> (wallet_id IS NOT NULL)",
      name: "chk_triggered_alerts_subscription_xor_wallet",
      validate: false

    add_index :usage_monitoring_alerts,
      %w[wallet_id organization_id alert_type],
      unique: true,
      name: "idx_alerts_unique_per_type_per_wallet",
      where: "(billable_metric_id IS NULL AND deleted_at IS NULL)",
      algorithm: :concurrently
  end
end
