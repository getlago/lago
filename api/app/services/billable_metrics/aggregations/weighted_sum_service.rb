# frozen_string_literal: true

module BillableMetrics
  module Aggregations
    class WeightedSumService < BillableMetrics::Aggregations::BaseService
      def initialize(...)
        super

        event_store.numeric_property = true
        event_store.aggregation_property = billable_metric.field_name
      end

      def compute_aggregation(*)
        return empty_result if should_bypass_aggregation?

        weighted_result = event_store.weighted_sum(initial_value:)

        result.aggregation = weighted_result.value.ceil(20)
        result.count = weighted_result.events_count
        result.variation = weighted_result.variation
        result.total_aggregated_units = result.variation
        result.options = {}

        if presentation_by.present?
          initial_breakdowns = billable_metric.recurring? ? latest_breakdowns : []
          result.breakdowns = event_store.grouped_weighted_sum(
            uniq_grouped_by_and_presentation_by,
            initial_values: initial_breakdowns.map(&:with_indifferent_access)
          ).map(&:to_grouped_hash)
        end

        if billable_metric.recurring?
          result.total_aggregated_units = latest_value + result.variation
          result.recurring_updated_at = event_store.last_event&.timestamp || from_datetime
          result.breakdowns = latest_breakdowns if result.breakdowns.blank?
        end

        result
      end

      # NOTE: Apply the grouped_by filter to the aggregation
      #       Result will have an aggregations attribute
      #       containing the aggregation result of each group.
      def compute_grouped_by_aggregation(*)
        return empty_results if should_bypass_aggregation?

        aggregations = event_store.grouped_weighted_sum(initial_values: grouped_latest_values)
        return empty_results if aggregations.blank?

        latest_values = []
        last_events = []
        if billable_metric.recurring?
          latest_values = grouped_latest_values
          last_events = event_store.grouped_last_event
        end

        if presentation_by.present?
          initial_breakdowns = billable_metric.recurring? ? grouped_latest_breakdowns : []
          result.breakdowns = event_store.grouped_weighted_sum(
            uniq_grouped_by_and_presentation_by,
            initial_values: initial_breakdowns.map(&:with_indifferent_access)
          ).map(&:to_grouped_hash)
          result.breakdowns = grouped_latest_breakdowns if result.breakdowns.empty?
        end

        result.aggregations = aggregations.map do |aggregation|
          group_result = BaseService::Result.new
          group_result.grouped_by = aggregation.groups

          group_result.aggregation = aggregation.value
          group_result.count = aggregation.events_count
          group_result.variation = aggregation.variation
          group_result.total_aggregated_units = group_result.variation

          if billable_metric.recurring?
            latest_value = latest_values.find { |c| c[:groups] == aggregation.groups }&.[](:value) || 0
            last_event = last_events.find { |c| c[:groups] == aggregation.groups }

            group_result.total_aggregated_units = latest_value + group_result.variation
            group_result.recurring_updated_at = last_event&.[](:timestamp) || from_datetime
          end

          group_result
        end

        result
      end

      private

      def initial_value
        return 0 unless billable_metric.recurring?

        latest_value
      end

      def latest_value
        return @latest_value if defined?(@latest_value)

        if latest_cached_aggregation
          return @latest_value = latest_cached_aggregation.current_aggregation
        end

        if subscription.previous_subscription_id?
          return @latest_value = latest_value_from_events.first
        end

        @latest_value = BigDecimal(0)
      end

      def latest_breakdowns
        return @latest_breakdowns if defined?(@latest_breakdowns)

        if latest_cached_aggregation
          return @latest_breakdowns = latest_cached_aggregation.presentation_breakdowns
        end

        if subscription.previous_subscription_id?
          return @latest_breakdowns = latest_value_from_events.second
        end

        @latest_breakdowns = []
      end

      def latest_cached_aggregation
        return @latest_cached_aggregation if defined?(@latest_cached_aggregation)

        @latest_cached_aggregation = latest_cached_aggregations
          .where(grouped_by: grouped_by.presence || {})
          .first
      end

      def latest_cached_aggregations
        return @latest_cached_aggregations if defined?(@latest_cached_aggregations)

        query = CachedAggregation
          .where(organization_id: billable_metric.organization_id)
          .where(external_subscription_id: subscription.external_id)
          .where(charge_id: charge.id)
          .where(timestamp: ...from_datetime)
          .order(timestamp: :desc, created_at: :desc)

        query = query.where(charge_filter_id: charge_filter.id) if charge_filter

        @latest_cached_aggregations = query
      end

      # NOTE: In case of upgrade/downgrade, if latest value is not persisted yet,
      #       we need to fetch latest value from previous events attached to the same external subscription ID
      def latest_value_from_events
        return @latest_value_from_events if defined?(@latest_value_from_events)

        event_store = event_store_class.new(
          code: billable_metric.code,
          subscription:,
          boundaries: {to_datetime: from_datetime - 1.second},
          filters:
        )

        event_store.use_from_boundary = false
        event_store.aggregation_property = billable_metric.field_name
        event_store.numeric_property = true

        breakdowns = presentation_by.present? ? event_store.grouped_sum(uniq_grouped_by_and_presentation_by, with_count: false).map(&:to_grouped_hash) : []

        @latest_value_from_events = [BigDecimal(event_store.sum(with_count: false).value), breakdowns]
      end

      def grouped_latest_values
        return @grouped_latest_values if defined?(@grouped_latest_values)

        if grouped_latest_cached_aggregations.any?
          return @grouped_latest_values = grouped_latest_cached_aggregations.map do |cached_aggregation|
            {
              groups: cached_aggregation.grouped_by,
              value: cached_aggregation.current_aggregation
            }
          end
        end

        if subscription.previous_subscription_id?
          return @grouped_latest_values = grouped_latest_values_from_events.first
        end

        @grouped_latest_values = {}
      end

      def grouped_latest_breakdowns
        return @grouped_latest_breakdowns if defined?(@grouped_latest_breakdowns)

        if grouped_latest_cached_aggregations.any?
          return @grouped_latest_breakdowns = grouped_latest_cached_aggregations.flat_map(&:presentation_breakdowns)
        end

        if subscription.previous_subscription_id?
          return @grouped_latest_breakdowns = grouped_latest_values_from_events.second
        end

        @grouped_latest_breakdowns = []
      end

      def grouped_latest_cached_aggregations
        return @grouped_latest_cached_aggregations if defined?(@grouped_latest_cached_aggregations)

        query = latest_cached_aggregations

        grouped_by.each do |key|
          query = query.where("grouped_by?:key", key:)
        end

        @grouped_latest_cached_aggregations = query.to_a
      end

      def grouped_latest_values_from_events
        event_store = event_store_class.new(
          code: billable_metric.code,
          subscription:,
          boundaries: {to_datetime: from_datetime - 1.second},
          filters:
        )

        event_store.use_from_boundary = false
        event_store.aggregation_property = billable_metric.field_name
        event_store.numeric_property = true

        breakdowns = presentation_by.present? ? event_store.grouped_sum(uniq_grouped_by_and_presentation_by, with_count: false).map(&:to_grouped_hash) : []

        [event_store.grouped_sum(with_count: false).map(&:to_grouped_hash), breakdowns]
      end
    end
  end
end
