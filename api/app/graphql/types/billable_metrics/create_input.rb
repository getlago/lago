# frozen_string_literal: true

module Types
  module BillableMetrics
    class CreateInput < BaseInputObject
      description "Create Billable metric input arguments"

      argument :aggregation_type, Types::BillableMetrics::AggregationTypeEnum, required: true
      argument :code, String, required: true
      argument :description, String
      argument :expression, String, required: false
      argument :field_name, String, required: false
      argument :name, String, required: true
      argument :recurring, Boolean, required: false
      argument :rounding_function, Types::BillableMetrics::RoundingFunctionEnum, required: false
      argument :rounding_precision, Integer, required: false
      argument :weighted_interval, Types::BillableMetrics::WeightedIntervalEnum, required: false

      argument :filters, [Types::BillableMetricFilters::Input], required: false
    end
  end
end
