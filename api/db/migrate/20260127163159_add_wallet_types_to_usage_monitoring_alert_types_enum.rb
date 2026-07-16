# frozen_string_literal: true

class AddWalletTypesToUsageMonitoringAlertTypesEnum < ActiveRecord::Migration[8.0]
  def change
    add_enum_value :usage_monitoring_alert_types, "wallet_balance_amount", if_not_exists: true
    add_enum_value :usage_monitoring_alert_types, "wallet_credits_balance", if_not_exists: true
  end
end
