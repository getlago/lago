# frozen_string_literal: true

module Types
  module BillableMetrics
    class AggregationTypeEnum < Types::BaseEnum
      BillableMetric::AGGREGATION_TYPES.keys.each do |type|
        value type
      end
    end
  end
end
