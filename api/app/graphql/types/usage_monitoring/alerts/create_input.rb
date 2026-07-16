# frozen_string_literal: true

module Types
  module UsageMonitoring
    module Alerts
      class CreateInput < BaseInputObject
        argument :alert_type, Types::UsageMonitoring::Alerts::AlertTypeEnum, required: true

        argument :billable_metric_id, ID, required: false
        argument :code, String, required: true
        argument :name, String, required: false
        argument :subscription_id, ID, required: false
        argument :wallet_id, ID, required: false

        argument :thresholds, [Types::UsageMonitoring::Alerts::ThresholdInput], required: true
      end
    end
  end
end
