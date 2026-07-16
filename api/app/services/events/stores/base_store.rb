# frozen_string_literal: true

module Events
  module Stores
    class BaseStore
      AggregationResult = Data.define(
        :value,
        :events_count
      )

      # NOTE: result of a grouped aggregation. Mirrors AggregationResult but also
      #       carries the group it belongs to.
      GroupedAggregationResult = Data.define(
        :groups,
        :value,
        :events_count
      ) do
        def to_grouped_hash
          {groups:, value:}
        end
      end

      # NOTE: result of a weighted_sum aggregation. Unlike AggregationResult it also
      #       carries the variation (sum of the real events) alongside the weighted value.
      WeightedAggregationResult = Data.define(
        :value,       # weighted aggregation (units per second)
        :variation,   # sum of real events (initial_value already subtracted)
        :events_count
      )

      # NOTE: grouped variant of WeightedAggregationResult.
      GroupedWeightedAggregationResult = Data.define(
        :groups,
        :value,
        :variation,
        :events_count
      ) do
        def to_grouped_hash
          {groups:, value:}
        end
      end

      # NOTE: result of a prorated_sum aggregation. Unlike AggregationResult it also
      #       carries the raw, non-prorated value alongside the events count
      ProratedAggregationResult = Data.define(
        :value,           # non-prorated sum
        :prorated_value,  # prorated sum (value * ratio)
        :events_count
      )

      # NOTE: grouped variant of ProratedAggregationResult.
      GroupedProratedAggregationResult = Data.define(
        :groups,
        :value,
        :prorated_value,
        :events_count
      )

      def initialize(subscription:, boundaries:, code: nil, filters: {}, deduplicate: false)
        @code = code
        @subscription = subscription
        @boundaries = boundaries

        @filters = filters

        @grouped_by = filters[:grouped_by]
        @grouped_by_values = filters[:grouped_by_values]

        @charge_id = filters[:charge_id]
        @charge_filter_id = filters[:charge_filter]&.id
        @matching_filters = filters[:matching_filters] || {}
        @ignored_filters = filters[:ignored_filters] || []

        @aggregation_property = nil
        @numeric_property = false
        @use_from_boundary = true
        @deduplicate = deduplicate
      end

      def grouped_by_values?
        grouped_by_values.present?
      end

      def with_grouped_by_values(grouped_by_values, &block)
        previous_grouped_by_values = @grouped_by_values
        return yield block if grouped_by_values.nil?

        @grouped_by_values = grouped_by_values
        yield block
      ensure
        @grouped_by_values = previous_grouped_by_values
      end

      def events(force_from: false)
        raise NotImplementedError
      end

      def events_values(limit: nil, force_from: false)
        raise NotImplementedError
      end

      def last_event
        raise NotImplementedError
      end

      def distinct_codes_and_property_combinations(codes:, filter_keys:)
        nil
      end

      def prorated_events_values(total_duration)
        raise NotImplementedError
      end

      def count
        raise NotImplementedError
      end

      def grouped_count
        raise NotImplementedError
      end

      def max(with_count: true)
        raise NotImplementedError
      end

      def grouped_max(columns = grouped_by, with_count: true)
        raise NotImplementedError
      end

      def last(with_count: true)
        raise NotImplementedError
      end

      def grouped_last(with_count: true)
        raise NotImplementedError
      end

      def sum(with_count: true)
        raise NotImplementedError
      end

      def grouped_sum(with_count: true)
        raise NotImplementedError
      end

      def sum_precise_total_amount_cents
        raise NotImplementedError
      end

      def grouped_sum_precise_total_amount_cents
        raise NotImplementedError
      end

      def prorated_sum(period_duration:, persisted_duration: nil)
        raise NotImplementedError
      end

      def grouped_prorated_sum(period_duration:, persisted_duration: nil)
        raise NotImplementedError
      end

      # NOTE: returns the breakdown of the sum grouped by date
      #       The result format will be an array of hash with the format:
      #       [{ date: Date.parse('2023-11-27'), value: 12.9 }, ...]
      def sum_date_breakdown
        raise NotImplementedError
      end

      def weighted_sum(initial_value: 0)
        raise NotImplementedError
      end

      def grouped_weighted_sum(initial_values: [])
        raise NotImplementedError
      end

      def from_datetime
        boundaries[:from_datetime]&.to_time&.floor(3)
      end

      def to_datetime
        boundaries[:to_datetime]
      end

      def charges_duration
        boundaries[:charges_duration]
      end

      def applicable_to_datetime
        boundaries[:max_timestamp] || to_datetime
      end

      def sanitize_colon(query)
        # NOTE: escape ':' to avoid ActiveRecord::PreparedStatementInvalid,
        query.gsub("'#{code}'", "'#{code.gsub(":", "\\:")}'")
      end

      def timezone
        @timezone ||= customer.applicable_timezone
      end

      # NOTE: This method is used mainly for WeightedSumQuery and UniqueCountQuery.
      #
      # The idea is to identify when the grouped_by includes the presentation_by,
      # so we decide when to use the sorted_grouped_by (only grouped_by from filters) or sorted_properties (grouped_by + presentation_by).
      def with_presentation_by_in_grouped_by?
        return false if grouped_by.blank?

        filters[:presentation_by].present? && (grouped_by & filters[:presentation_by]).size.positive?
      end

      attr_accessor :numeric_property, :aggregation_property, :use_from_boundary, :grouped_by, :charge_id, :charge_filter_id

      protected

      attr_accessor :code, :subscription, :boundaries, :grouped_by_values, :filters, :matching_filters, :ignored_filters, :deduplicate

      delegate :customer, to: :subscription

      def period_duration
        @period_duration ||= Subscriptions::DatesService.new_instance(
          subscription,
          to_datetime + 1.day,
          current_usage: subscription.terminated? && subscription.upgraded?
        ).charges_duration_in_days
      end

      def build_aggregation_result(row)
        AggregationResult.new(
          value: row["value"] || 0,
          events_count: row["events_count"].presence&.to_i
        )
      end

      # NOTE: Build an AggregationResult for the `last` aggregation. Unlike
      #       build_aggregation_result it preserves a nil value (no event or no
      #       value on the last event) instead of defaulting to 0, and tolerates
      #       an empty row (when LIMIT 1 returns no row, events_count is 0).
      #       The value is returned as-is from the driver (numeric), consistent
      #       with sum/max/grouped_* which also don't cast.
      def build_last_aggregation_result(row, with_count: true)
        AggregationResult.new(
          value: row && row["value"],
          events_count: with_count ? (row && row["events_count"]).to_i : nil
        )
      end

      # NOTE: Build a ProratedAggregationResult from the raw query columns. Mirrors
      #       build_aggregation_result but also carries the prorated value.
      def build_prorated_aggregation_result(row)
        ProratedAggregationResult.new(
          value: row["value"] || 0,
          prorated_value: row["prorated_value"] || 0,
          events_count: row["events_count"].presence&.to_i
        )
      end

      # NOTE: grouped variant of build_prorated_aggregation_result.
      def build_grouped_prorated_aggregation_result(groups:, value:, prorated_value:, events_count:)
        GroupedProratedAggregationResult.new(
          groups:,
          value: value || 0,
          prorated_value: prorated_value || 0,
          events_count: events_count.presence&.to_i
        )
      end

      # NOTE: Build an AggregationResult for aggregations whose value already
      #       represents the number of aggregated events (count, unique_count).
      #       The value is reused as the events_count, avoiding a second count query.
      def build_aggregation_result_from_value(value)
        value ||= 0
        AggregationResult.new(value:, events_count: value)
      end

      # NOTE: same as build_aggregation_result_from_value but for grouped results:
      #       wraps {groups:, value:} hashes into GroupedAggregationResult,
      #       reusing each value as its events_count.
      def grouped_results_with_value_as_count(rows)
        rows.map do |row|
          GroupedAggregationResult.new(groups: row[:groups], value: row[:value], events_count: row[:value])
        end
      end

      # NOTE: builds a WeightedAggregationResult from the raw query columns.
      def build_weighted_aggregation_result(value:, variation_with_initial:, rows_count:, initial_value:)
        WeightedAggregationResult.new(
          value:,
          variation: variation_with_initial - (initial_value || 0).to_d, # Subtract initial value from variation
          events_count: [rows_count - 2, 0].max # Handle zero duration case
        )
      end

      # NOTE: Build the { column => value } groups hash used by grouped aggregation results.
      def build_groups(values, columns: grouped_by)
        columns.zip(values.map(&:presence)).to_h
      end

      # NOTE: grouped variant of build_weighted_aggregation_result.
      def build_grouped_weighted_result(groups:, value:, variation_with_initial:, rows_count:, initial_values:)
        initial_value = initial_values.find { |iv| iv[:groups] == groups }&.fetch(:value, 0)

        weighted = build_weighted_aggregation_result(
          value:,
          variation_with_initial:,
          rows_count:,
          initial_value:
        )

        GroupedWeightedAggregationResult.new(
          groups:,
          value: weighted.value,
          variation: weighted.variation,
          events_count: weighted.events_count
        )
      end
    end
  end
end
