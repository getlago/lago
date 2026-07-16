# frozen_string_literal: true

module BillableMetrics
  module ProratedAggregations
    class SumService < BillableMetrics::ProratedAggregations::BaseService
      PERSISTED_TOP_BOUNDARY_DELAY = 0.000001.seconds

      def initialize(**args)
        super
        @base_aggregator = BillableMetrics::Aggregations::SumService.new(**args)
        @base_aggregator.result = result

        event_store.numeric_property = true
        event_store.aggregation_property = billable_metric.field_name
      end

      def compute_aggregation(options: {})
        return base_aggregator.aggregate(options:) if bill_full_amount?(options)

        # NOTE: Inject the result in the non-prorated aggregator to avoid duplicated queries
        base_aggregator.injected_sum_result = non_prorated_sum_result
        aggregation_without_proration = base_aggregator.aggregate(options:)

        aggregation = compute_event_aggregation.ceil(5)
        result.full_units_number = aggregation_without_proration.aggregation if event.nil?

        if options[:is_current_usage]
          handle_current_usage(
            aggregation,
            options[:is_pay_in_advance],
            target_result: result,
            aggregation_without_proration:
          )
        else
          result.aggregation = aggregation
        end

        result.pay_in_advance_aggregation = compute_pay_in_advance_aggregation(aggregation_without_proration:)
        result.count = aggregation_without_proration.count

        if presentation_by.present?
          result.breakdowns = event_store.grouped_sum(uniq_grouped_by_and_presentation_by, with_count: false).map(&:to_grouped_hash)
          result.pay_in_advance_breakdowns = build_pay_in_advance_breakdowns(value: event_value)
        end

        result.options = options
        result
      rescue ActiveRecord::StatementInvalid => e
        result.service_failure!(code: "aggregation_failure", message: e.message)
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
        return base_aggregator.aggregate(options:) if bill_full_amount?(options)

        # NOTE: Inject the result in the non-prorated aggregator to avoid duplicated queries
        base_aggregator.injected_grouped_sum_result = non_prorated_grouped_sum_result
        aggregation_without_proration = base_aggregator.aggregate(options:)

        aggregations = compute_grouped_event_aggregation
        return empty_results if aggregations.blank?

        result.aggregations = aggregations.map do |aggregation|
          aggregation_value = aggregation[:value].ceil(5)

          group_result_without_proration = aggregation_without_proration.aggregations.find do |agg|
            agg.grouped_by == aggregation[:groups]
          end

          unless group_result_without_proration
            group_result_without_proration = empty_results.aggregations.first
            group_result_without_proration.grouped_by = aggregation[:groups]
          end

          group_result = BaseService::Result.new
          group_result.grouped_by = aggregation[:groups]
          group_result.full_units_number = group_result_without_proration&.aggregation || 0

          if options[:is_current_usage]
            handle_current_usage(
              aggregation_value,
              options[:is_pay_in_advance],
              target_result: group_result,
              aggregation_without_proration: group_result_without_proration
            )
          else
            group_result.aggregation = aggregation_value
          end

          group_result.count = group_result_without_proration&.count || 0
          group_result.options = options

          group_result
        end

        if presentation_by.present?
          result.breakdowns = event_store.grouped_sum(uniq_grouped_by_and_presentation_by, with_count: false).map(&:to_grouped_hash)
        end

        result
      rescue ActiveRecord::StatementInvalid => e
        result.service_failure!(code: "aggregation_failure", message: e.message)
      end

      def compute_per_event_prorated_aggregation
        event_store.prorated_events_values(period_duration)
      end

      def per_event_aggregation(exclude_event: false, include_event_value: false, grouped_by_values: nil)
        recurring_result = recurring_value
        recurring_aggregation = recurring_result ? [BigDecimal(recurring_result)] : []
        recurring_prorated_aggregation = recurring_result ? [BigDecimal(recurring_result) * persisted_pro_rata] : []

        ProratedPerEventAggregationResult.new.tap do |result|
          result.event_aggregation = recurring_aggregation +
            base_aggregator.per_event_aggregation(exclude_event:, grouped_by_values:).event_aggregation

          event_store.with_grouped_by_values(grouped_by_values) do
            result.event_prorated_aggregation = recurring_prorated_aggregation +
              compute_per_event_prorated_aggregation
          end
        end
      end

      protected

      # NOTE: pay in advance charges billed on the billing date (no event, not current usage)
      #       always bill the full amount, so proration is not applied.
      def bill_full_amount?(options)
        event.nil? && options[:is_pay_in_advance] && !options[:is_current_usage]
      end

      def persisted_event_store_instance
        @persisted_event_store_instance ||= begin
          event_store = event_store_class.new(
            code: billable_metric.code,
            subscription:,
            boundaries: {to_datetime: from_datetime - PERSISTED_TOP_BOUNDARY_DELAY}, # Note: Avoid counting events exactly on `from_datetime` twice
            filters:,
            deduplicate: deduplicate?
          )

          event_store.use_from_boundary = false
          event_store.aggregation_property = billable_metric.field_name
          event_store.numeric_property = true
          event_store
        end
      end

      def compute_event_aggregation
        # NOTE: persisted value is billed on the full period, current value is added during the period
        (persisted_prorated_result.prorated_value || 0) + (current_prorated_result.prorated_value || 0)
      end

      # NOTE: prorated sum of the events added during the current period.
      def current_prorated_result
        @current_prorated_result ||= event_store.prorated_sum(period_duration:)
      end

      # NOTE: prorated sum of the events persisted before the current period.
      def persisted_prorated_result
        @persisted_prorated_result ||= persisted_event_store_instance.prorated_sum(
          period_duration:,
          persisted_duration: subscription.date_diff_with_timezone(from_datetime, to_datetime)
        )
      end

      # NOTE: rebuilds the non-prorated AggregationResult for the base aggregator
      def non_prorated_sum_result
        current = current_prorated_result

        unless billable_metric.recurring
          return Events::Stores::BaseStore::AggregationResult.new(
            value: current.value || 0,
            events_count: current.events_count
          )
        end

        persisted = persisted_prorated_result
        Events::Stores::BaseStore::AggregationResult.new(
          value: (persisted.value || 0) + (current.value || 0), # TODO: Refactor to inject persisted value
          events_count: (persisted.events_count || 0) + (current.events_count || 0)
        )
      end

      def recurring_value(grouped_by_values: nil)
        # NOTE: for the ungrouped case the persisted non-prorated sum is already computed
        #       by persisted_prorated_result, so we reuse it instead of querying again.
        raw_sum = if grouped_by_values.present?
          store = persisted_event_store_instance
          store.with_grouped_by_values(grouped_by_values) { store.sum(with_count: false).value }
        else
          persisted_prorated_result.value
        end

        return nil if raw_sum.nil? || raw_sum.zero?

        raw_sum
      end

      def compute_grouped_event_aggregation
        # NOTE: persisted values are billed on the full period, current values are added during the period
        results = persisted_grouped_prorated_results + current_grouped_prorated_results

        results.group_by(&:groups).map do |groups, group_results|
          {groups:, value: group_results.sum { |r| r.prorated_value || 0 }}
        end
      end

      # NOTE: rebuilds the per-group non-prorated AggregationResult for the base aggregator
      def non_prorated_grouped_sum_result
        results = current_grouped_prorated_results
        results += persisted_grouped_prorated_results if billable_metric.recurring

        results.group_by(&:groups).map do |groups, group_results|
          Events::Stores::BaseStore::GroupedAggregationResult.new(
            groups:,
            value: group_results.sum { |r| r.value || 0 },
            events_count: group_results.sum { |r| r.events_count || 0 }
          )
        end
      end

      def current_grouped_prorated_results
        @current_grouped_prorated_results ||= event_store.grouped_prorated_sum(period_duration:)
      end

      def persisted_grouped_prorated_results
        @persisted_grouped_prorated_results ||= persisted_event_store_instance.grouped_prorated_sum(
          period_duration:,
          persisted_duration: subscription.date_diff_with_timezone(from_datetime, to_datetime)
        )
      end
    end
  end
end
