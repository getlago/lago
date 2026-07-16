# frozen_string_literal: true

module BillableMetrics
  module Aggregations
    class LatestService < BillableMetrics::Aggregations::BaseService
      def initialize(...)
        super

        event_store.numeric_property = true
        event_store.aggregation_property = billable_metric.field_name
      end

      def compute_aggregation(options: {})
        return empty_result if should_bypass_aggregation?

        last_result = event_store.last

        result.aggregation = compute_aggregation_value(last_result.value)
        result.count = last_result.events_count

        if presentation_by.present?
          result.breakdowns = event_store.grouped_last(uniq_grouped_by_and_presentation_by, with_count: false).map(&:to_grouped_hash)
        end

        result.options = options
        result
      rescue ActiveRecord::StatementInvalid => e
        result.service_failure!(code: "aggregation_failure", message: e.message)
      end

      # NOTE: Apply the grouped_by filter to the aggregation
      #       Result will have an aggregations attribute
      #       containing the aggregation result of each group
      def compute_grouped_by_aggregation(*)
        return empty_results if should_bypass_aggregation?

        aggregations = event_store.grouped_last
        return empty_results if aggregations.blank?

        result.aggregations = aggregations.map do |aggregation|
          group_result = BaseService::Result.new
          group_result.grouped_by = aggregation.groups
          group_result.aggregation = compute_aggregation_value(aggregation.value)
          group_result.count = aggregation.events_count || 0
          group_result
        end

        if presentation_by.present?
          result.breakdowns = event_store.grouped_last(uniq_grouped_by_and_presentation_by, with_count: false).map(&:to_grouped_hash)
        end

        result
      rescue ActiveRecord::StatementInvalid => e
        result.service_failure!(code: "aggregation_failure", message: e.message)
      end

      protected

      def compute_aggregation_value(latest_value)
        result = BigDecimal((latest_value || 0).to_s)
        return BigDecimal(0) if result.negative?

        result
      end
    end
  end
end
