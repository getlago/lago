# frozen_string_literal: true

module Types
  module BillableMetrics
    class RoundingFunctionEnum < Types::BaseEnum
      BillableMetric::ROUNDING_FUNCTIONS.values.each do |type|
        value type
      end
    end
  end
end
