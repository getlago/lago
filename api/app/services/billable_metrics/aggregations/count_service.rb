# frozen_string_literal: true

module BillableMetrics
  module Aggregations
    class CountService < BillableMetrics::Aggregations::BaseService
      def compute_aggregation(options: {})
        return empty_result if should_bypass_aggregation?

        count_result = event_store.count
        result.aggregation = count_result.value
        result.current_usage_units = count_result.value
        result.count = count_result.events_count
        result.pay_in_advance_aggregation = BigDecimal(1)

        if presentation_by.present?
          result.breakdowns = event_store.grouped_count(uniq_grouped_by_and_presentation_by).map(&:to_grouped_hash)
          result.pay_in_advance_breakdowns = build_pay_in_advance_breakdowns(value: 1)
        end

        result.options = {running_total: running_total(options, aggregation: result.aggregation)}
        result
      end

      # NOTE: Apply the grouped_by filter to the aggregation
      #       Result will have an aggregations attribute
      #       containing the aggregation result of each group.
      #
      #       This logic is only applicable for in arrears aggregation
      #       (exept for the current_usage update)
      #       as pay in advance aggregation will be computed on a single group
      #       with the grouped_by_values filter
      def compute_grouped_by_aggregation(options: {})
        return empty_results if should_bypass_aggregation?

        aggregations = event_store.grouped_count
        return empty_results if aggregations.blank?

        result.aggregations = aggregations.map do |aggregation|
          group_result = BaseService::Result.new
          group_result.grouped_by = aggregation.groups
          group_result.aggregation = aggregation.value
          group_result.count = aggregation.events_count
          group_result.current_usage_units = aggregation.value
          group_result.options = {running_total: running_total(options, aggregation: group_result.aggregation)}
          group_result
        end

        if presentation_by.present?
          result.breakdowns = event_store.grouped_count(uniq_grouped_by_and_presentation_by).map(&:to_grouped_hash)
        end

        result
      end

      # NOTE: Return cumulative sum of event count based on the number of free units
      #       (per_events or per_total_aggregation).
      def running_total(options, aggregation:)
        free_units_per_events = options[:free_units_per_events].to_i
        free_units_per_total_aggregation = BigDecimal(options[:free_units_per_total_aggregation] || 0)

        return [] if free_units_per_events.zero? && free_units_per_total_aggregation.zero?

        (1..aggregation).to_a
      end

      def compute_per_event_aggregation(exclude_event:, include_event_value:)
        values = (0...event_store.count.value).map { |_| 1 }
        values << 1 if include_event_value
        values
      end
    end
  end
end
