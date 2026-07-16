# frozen_string_literal: true

module BillableMetrics
  module Aggregations
    class MaxService < BillableMetrics::Aggregations::BaseService
      def initialize(...)
        super

        event_store.numeric_property = true
        event_store.aggregation_property = billable_metric.field_name
      end

      def compute_aggregation(options: {})
        return empty_result if should_bypass_aggregation?

        max_result = event_store.max

        result.aggregation = max_result.value
        result.count = max_result.events_count

        if presentation_by.present?
          result.breakdowns = event_store.grouped_max(uniq_grouped_by_and_presentation_by, with_count: false).map(&:to_grouped_hash)
        end

        result.options = options
        result
      rescue ActiveRecord::StatementInvalid => e
        result.service_failure!(code: "aggregation_failure", message: e.message)
      end

      def compute_grouped_by_aggregation(options)
        return empty_results if should_bypass_aggregation?

        aggregations = event_store.grouped_max
        return empty_results if aggregations.blank?

        result.aggregations = aggregations.map do |aggregation|
          group_result = BaseService::Result.new
          group_result.grouped_by = aggregation.groups
          group_result.aggregation = aggregation.value
          group_result.options = options
          group_result.count = aggregation.events_count || 0
          group_result
        end

        if presentation_by.present?
          result.breakdowns = event_store.grouped_max(uniq_grouped_by_and_presentation_by, with_count: false).map(&:to_grouped_hash)
        end

        result
      rescue ActiveRecord::StatementInvalid => e
        result.service_failure!(code: "aggregation_failure", message: e.message)
      end

      # Note: include_event_value is ignored as the model does not support in advance billing
      def compute_per_event_aggregation(exclude_event:, include_event_value:)
        max_value = event_store.max(with_count: false).value
        event_values = event_store.events_values
        max_value_seen = false

        # NOTE: returns the first max value, 0 for all other events
        event_values.map do |value|
          if !max_value_seen && value == max_value
            max_value_seen = true

            next value
          end

          0
        end
      end
    end
  end
end
