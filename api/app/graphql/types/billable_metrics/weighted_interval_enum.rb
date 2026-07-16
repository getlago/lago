# frozen_string_literal: true

module Types
  module BillableMetrics
    class WeightedIntervalEnum < Types::BaseEnum
      BillableMetric::WEIGHTED_INTERVAL.values.each do |type|
        value type
      end
    end
  end
end
