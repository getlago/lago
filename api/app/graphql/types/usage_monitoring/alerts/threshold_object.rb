# frozen_string_literal: true

module Types
  module UsageMonitoring
    module Alerts
      class ThresholdObject < Types::BaseObject
        graphql_name "AlertThreshold"

        field :code, String, null: true
        field :recurring, Boolean, null: false
        field :value, String, null: false
      end
    end
  end
end
