# frozen_string_literal: true

module BillableMetrics
  module Aggregations
    class CustomService < BillableMetrics::Aggregations::BaseService
      # NOTE: DEPRECATED service

      INITIAL_STATE = {total_units: BigDecimal(0), amount: BigDecimal(0)}.freeze
      BATCH_SIZE = 1000

      def compute_aggregation(options: {})
        return empty_result if should_bypass_aggregation?

        result.count = event_store.count.value

        aggregation_result = perform_custom_aggregation(grouped_by_values:)
        in_advance_aggregation_result = compute_pay_in_advance_aggregation

        result.aggregation = aggregation_result[:total_units]
        result.current_usage_units = result.aggregation
        result.custom_aggregation = event ? in_advance_aggregation_result : aggregation_result
        result.options = options
        result.pay_in_advance_aggregation = in_advance_aggregation_result[:total_units]

        # NOTE: Compute refresh time for cached aggregation
        result.recurring_updated_at = event_store.last_event&.timestamp || from_datetime if billable_metric.recurring?

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

        counts = event_store.grouped_count
        return empty_results if counts.blank?

        last_events = []
        last_events = event_store.grouped_last_event if billable_metric.recurring?

        result.aggregations = counts.map do |aggregation|
          group_result = BaseService::Result.new
          group_result.grouped_by = aggregation.groups
          group_result.count = aggregation.events_count

          aggregation_result = perform_custom_aggregation(
            target_result: group_result,
            grouped_by_values: aggregation.groups
          )

          group_result.aggregation = aggregation_result[:total_units]
          group_result.current_usage_units = group_result.aggregation
          group_result.custom_aggregation = aggregation_result
          group_result.options = options

          if billable_metric.recurring?
            last_event = last_events.find { |c| c[:groups] == aggregation.groups }

            group_result.recurring_updated_at = last_event&.[](:timestamp) || from_datetime
          end

          group_result
        end

        result
      end

      def compute_per_event_aggregation(exclude_event:, include_event_value:)
        # TODO: Implement custom aggregation logic returning 1 value per event
        event_store.events_properties
      end

      private

      def custom_properties
        return charge_filter.properties["custom_properties"] if charge_filter.present?

        charge.properties["custom_properties"]
      end

      def current_state(grouped_by_values:)
        return latest_state(grouped_by_values:) if billable_metric.recurring?

        INITIAL_STATE
      end

      def latest_state(grouped_by_values:)
        truncated_datetime = to_datetime.change(usec: 0)

        query = CachedAggregation
          .where(organization_id: billable_metric.organization_id)
          .where(external_subscription_id: subscription.external_id)
          .where(charge_id: charge.id)
          .where("cached_aggregations.timestamp < ?", truncated_datetime)
          .where(grouped_by: grouped_by_values.presence || {})
          .order(timestamp: :desc, created_at: :desc)

        query = query.where(charge_filter_id: charge_filter.id) if charge_filter
        cached_aggregation = query.first

        if cached_aggregation
          return {
            total_units: cached_aggregation.current_aggregation,
            amount: cached_aggregation.current_amount
          }
        end

        # TODO: fetch latest state from the previous subscription

        INITIAL_STATE
      end

      def perform_custom_aggregation(target_result: result, grouped_by_values: nil)
        total_batches = (target_result.count.to_f / BATCH_SIZE).ceil
        state = current_state(grouped_by_values:)

        # NOTE: for grouped_by aggregations we need to initialize
        #       the event store with the grouped_by values to only fetch the events
        #       of the group
        store = event_store
        if grouped_by_values
          store = event_store_class.new(
            code: billable_metric.code,
            subscription:,
            boundaries:,
            filters: filters.merge(grouped_by_values:)
          )
        end

        # NOTE: Loop over events by batch
        (1..total_batches).each do |batch|
          events_properties = store.events(ordered: true).page(batch).per(BATCH_SIZE)
            .map { |event| {timestamp: event.timestamp, properties: event.properties} }

          state = sandboxed_aggregation(events_properties, state)
        end

        state
      end

      def sandboxed_aggregation(events_properties, state)
        sandboxed_result = LagoUtils::RubySandbox.run(aggregator(events_properties, state))

        {
          total_units: BigDecimal(sandboxed_result["total_units"].to_s),
          amount: BigDecimal(sandboxed_result["amount"].to_s)
        }
      end

      def aggregator(events_properties, current_state)
        <<~RUBY
          class EventValues
            def initialize(timestamp:, properties:)
              @timestamp = timestamp
              @properties = properties
            end

            attr_reader :timestamp, :properties
          end

          initial_state = {
            total_units: BigDecimal('#{current_state[:total_units]}'),
            amount: BigDecimal('#{current_state[:amount]}')
          }

          aggregation_properties = JSON.parse('#{custom_properties.to_json}')

          #{billable_metric.custom_aggregator}

          events = [
            #{events_properties.map do |event|
              "EventValues.new(timestamp: Time.at(#{event[:timestamp].to_f}),properties: #{event[:properties].as_json})"
            end.join(",\n")}
          ]

          result = events.each_with_object(initial_state.dup) do |event, agg|
            res = aggregate(event, agg, aggregation_properties)

            agg[:total_units] = res[:total_units]
            agg[:amount] += res[:amount]
          end

          result
        RUBY
      end

      def compute_pay_in_advance_aggregation
        return INITIAL_STATE unless event

        cached_aggregation = find_cached_aggregation(
          with_from_datetime: from_datetime,
          with_to_datetime: to_datetime,
          grouped_by: grouped_by_values
        )

        # NOTE: The aggregation was never performed on the period,
        #       we need to perform a full aggregation and cache it
        unless cached_aggregation
          state = perform_custom_aggregation(grouped_by_values:)

          assign_cached_metadata(
            current_aggregation: state[:total_units],
            max_aggregation: state[:total_units],
            units_applied: state[:total_units],
            current_amount: state[:amount]
          )

          return state
        end

        # NOTE: Retrieve values from the previous aggregation
        old_aggregation = cached_aggregation.current_aggregation
        old_max = cached_aggregation.max_aggregation
        old_amount = cached_aggregation.current_amount

        # NOTE: compute aggregation for the current event, using the previous state
        event_aggregation = sandboxed_aggregation(
          [{timestamp: event.timestamp, properties: event.properties}],
          {total_units: old_aggregation, amount: old_amount}
        )

        units_applied = event_aggregation[:total_units] - old_aggregation
        max_aggregation = if event_aggregation[:total_units] > old_max
          event_aggregation[:total_units]
        else
          old_max
        end

        # NOTE: Update the metadata for the current event
        assign_cached_metadata(
          current_aggregation: event_aggregation[:total_units],
          max_aggregation:,
          units_applied:,
          current_amount: event_aggregation[:amount]
        )

        # NOTE: Return the amount and units to be charged for the current event
        {
          total_units: units_applied,
          amount: event_aggregation[:amount] - old_amount
        }
      end

      def assign_cached_metadata(current_aggregation:, max_aggregation:, units_applied: nil, current_amount: nil)
        result.current_aggregation = current_aggregation unless current_aggregation.nil?
        result.max_aggregation = max_aggregation unless max_aggregation.nil?
        result.units_applied = units_applied unless units_applied.nil?
        result.current_amount = current_amount unless current_amount.nil?
      end
    end
  end
end
