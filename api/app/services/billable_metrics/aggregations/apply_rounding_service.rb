# frozen_string_literal: true

module BillableMetrics
  module Aggregations
    class ApplyRoundingService < ::BaseService
      def initialize(billable_metric:, units:)
        @billable_metric = billable_metric
        @units = units

        super
      end

      def call
        precision = billable_metric.rounding_precision || 0

        result.units = case billable_metric.rounding_function&.to_sym
        when :ceil
          units.ceil(precision)
        when :floor
          units.floor(precision)
        when :round
          units.round(precision)
        else
          units
        end

        result
      end

      private

      attr_reader :billable_metric, :units
    end
  end
end
