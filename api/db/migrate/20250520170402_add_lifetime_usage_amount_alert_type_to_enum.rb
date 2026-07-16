# frozen_string_literal: true

class AddLifetimeUsageAmountAlertTypeToEnum < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    safety_assured do
      add_enum_value :usage_monitoring_alert_types, "lifetime_usage_amount", if_not_exists: true
    end
  end

  def down
  end
end
