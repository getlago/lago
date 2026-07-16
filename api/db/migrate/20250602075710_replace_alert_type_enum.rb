# frozen_string_literal: true

class ReplaceAlertTypeEnum < ActiveRecord::Migration[8.0]
  def change
    rename_enum_value :usage_monitoring_alert_types, from: "usage_amount", to: "current_usage_amount"
    rename_enum_value :usage_monitoring_alert_types, from: "billable_metric_usage_amount", to: "billable_metric_current_usage_amount"
    rename_enum_value :usage_monitoring_alert_types, from: "billable_metric_usage_units", to: "billable_metric_current_usage_units"
  end
end
