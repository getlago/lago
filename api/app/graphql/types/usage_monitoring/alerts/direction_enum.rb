# frozen_string_literal: true

module Types
  module UsageMonitoring
    module Alerts
      class DirectionEnum < Types::BaseEnum
        ::UsageMonitoring::Alert::DIRECTIONS.each_key do |direction|
          value direction
        end
      end
    end
  end
end
