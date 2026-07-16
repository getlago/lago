# frozen_string_literal: true

module Types
  module UsageMonitoring
    module Alerts
      class AlertTypeEnum < Types::BaseEnum
        ::UsageMonitoring::Alert::STI_MAPPING.keys.each do |type|
          value type
        end
      end
    end
  end
end
