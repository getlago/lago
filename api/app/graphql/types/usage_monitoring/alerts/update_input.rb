# frozen_string_literal: true

module Types
  module UsageMonitoring
    module Alerts
      class UpdateInput < BaseInputObject
        argument :id, ID, required: true

        argument :billable_metric_id, ID, required: false
        argument :code, String, required: false
        argument :name, String, required: false

        argument :thresholds, [Types::UsageMonitoring::Alerts::ThresholdInput], required: false
      end
    end
  end
end
