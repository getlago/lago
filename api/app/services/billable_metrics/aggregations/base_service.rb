# frozen_string_literal: true

module BillableMetrics
  module Aggregations
    class BaseService < ::BaseService
      Result = BaseResult[
        :aggregator, # Aggregator instance, used in some charge models
        :aggregations, # Array of aggregation result when in a grouped by scenario
        :aggregation, # Aggregation result computed using the event store
        :breakdowns, # Array of breakdowns when presentation_by is used
        :grouped_by, # Pricing group keys applied to this aggregation result
        :current_usage_units, # Number of aggregated units when computing the current usage
        :count, # Number of events used to compute the aggregation
        :full_units_number, # Total number of aggregated units without proration
        :options, # Extra options passed to the charge models (running_total, aggregation...)
        # Sum aggregation fields
        :precise_total_amount_cents, # Sum of events precise amount cents when billable metric is configured to use it
        # Weighted sum aggregation fields
        :total_aggregated_units, # Total number of active units for a weighted sum aggregation
        :variation, # Number of new active units on the current period for a weighted sum aggregation
        # Custom aggregation fields
        :current_amount, # Current amount computed in a custom aggregation scenario
        :custom_aggregation, # Custom aggregation result (Hash with total_units, and amount fields)
        # Pay in advance fields
        :pay_in_advance_event, # Event that is triggering a pay in advance aggregation
        :pay_in_advance_aggregation, # Aggregation result for a single pay in advance event
        :pay_in_advance_breakdowns, # Breakdown result for a single pay in advance event
        :pay_in_advance_precise_total_amount_cents, # Precise total amount in cents when in a pay in advance scenario
        # Cached aggregation fields
        :current_aggregation, # Current total aggregation cached in a pay in advance scenario (billing and current usage)
        :max_aggregation, # Maximum aggregation result cached in a pay in advance scenario (billing and current usage)
        :max_aggregation_with_proration, # Similar to max_aggregation but with proration on billing period applied
        :units_applied, # Number of units applied by the event and cached in a pay in advance scenario (billing and current usage)
        :recurring_updated_at # Date when the recurring cached aggregation was updated
      ]
      PerEventAggregationResult = BaseResult[:event_aggregation]

      def self.null_result(result, grouped_by_keys: nil, apply_aggregation: false)
        if apply_aggregation && grouped_by_keys.present?
          result.aggregations = [null_result(BaseService::Result.new, grouped_by_keys: grouped_by_keys)]
        else
          result.grouped_by = grouped_by_keys.index_with { nil } if grouped_by_keys
          result.aggregation = 0
          result.count = 0
          result.current_usage_units = 0
          result.options = {running_total: []}
        end
        result
      end

      def initialize(event_store_class:, charge:, subscription:, boundaries:, filters: {}, bypass_aggregation: false)
        super(nil)
        @event_store_class = event_store_class
        @charge = charge
        @subscription = subscription

        @filters = filters
        @charge_filter = filters[:charge_filter]
        @event = filters[:event]
        @grouped_by = filters[:grouped_by]
        @grouped_by_values = filters[:grouped_by_values]
        @presentation_by = filters[:presentation_by]
        @uniq_grouped_by_and_presentation_by = ((grouped_by || []) + (presentation_by || [])).uniq

        @boundaries = boundaries

        @bypass_aggregation = bypass_aggregation

        result.aggregator = self
        result.pay_in_advance_event = event if event
      end

      def aggregate(options: {})
        if grouped_by.present?
          compute_grouped_by_aggregation(options:)
          if charge.dynamic?
            compute_grouped_by_precise_total_amount_cents(options:)
          end

          result.aggregations.each { apply_rounding(it) }
        else
          compute_aggregation(options:)
          if charge.dynamic?
            compute_precise_total_amount_cents(options:)
          end

          apply_rounding(result)
        end
        result
      end

      def compute_aggregation(options: {})
        raise NotImplementedError
      end

      def compute_grouped_by_aggregation(options: {})
        raise NotImplementedError
      end

      def compute_precise_total_amount_cents(options: {})
        raise NotImplementedError
      end

      def compute_grouped_by_precise_total_amount_cents(options: {})
        raise NotImplementedError
      end

      # NOTE:
      # - With include_event_value: true, the current event (not yet persisted) will be included in the list of event values
      #   Used only for estimate_fees.
      # - With exclude_event: true, the current event (persisted) will be excluded from the list of event values
      #   Used only for in advance billing
      def per_event_aggregation(exclude_event: false, include_event_value: false, grouped_by_values: nil)
        PerEventAggregationResult.new.tap do |result|
          result.event_aggregation = event_store.with_grouped_by_values(grouped_by_values) do
            compute_per_event_aggregation(exclude_event:, include_event_value:)
          end
        end
      end

      # Exposes a null result that carries this aggregator instance, so downstream charge models
      # can dispatch `per_event_aggregation` through the real aggregator rather than nil.
      def empty_results
        self.class.null_result(result, grouped_by_keys: grouped_by, apply_aggregation: true)
        result
      end

      protected

      attr_accessor :event_store_class,
        :charge,
        :subscription,
        :filters,
        :charge_filter,
        :event,
        :boundaries,
        :grouped_by,
        :grouped_by_values,
        :presentation_by,
        :bypass_aggregation,
        :uniq_grouped_by_and_presentation_by

      delegate :billable_metric, to: :charge

      delegate :customer, to: :subscription

      def event_store
        @event_store ||= event_store_class.new(
          code: billable_metric.code,
          subscription:,
          boundaries:,
          filters:,
          deduplicate: deduplicate?
        )
      end

      def deduplicate?
        override = Events::Stores::StoreFactory.override
        return override[:deduplicate] if override

        organization = subscription&.organization
        return false unless organization

        organization.clickhouse_events_store? && organization.clickhouse_deduplication_enabled?
      end

      def from_datetime
        boundaries[:from_datetime]
      end

      def to_datetime
        boundaries[:to_datetime]
      end

      def event_value
        return unless event

        (event.properties || {})[billable_metric.field_name] || 0
      end

      def build_pay_in_advance_breakdowns(value:)
        return [] unless event
        return [] if event.properties.blank?

        groups = uniq_grouped_by_and_presentation_by.index_with { event.properties[it] }

        [{groups:, value: BigDecimal(value.to_s)}]
      end

      def handle_in_advance_current_usage(total_aggregation, target_result: result)
        cached_aggregation = find_cached_aggregation(
          with_from_datetime: from_datetime,
          with_to_datetime: to_datetime,
          grouped_by: target_result.grouped_by
        )

        if cached_aggregation
          aggregation = total_aggregation -
            BigDecimal(cached_aggregation.current_aggregation) +
            BigDecimal(cached_aggregation.max_aggregation)

          target_result.aggregation = aggregation
        else
          target_result.aggregation = total_aggregation
        end

        target_result.current_usage_units = total_aggregation

        target_result.aggregation = 0 if target_result.aggregation.negative?
        target_result.current_usage_units = 0 if target_result.current_usage_units.negative?
      end

      def should_bypass_aggregation?
        return false if billable_metric.recurring?

        bypass_aggregation
      end

      def empty_result
        self.class.null_result(result)
      end

      # This method fetches the latest cached aggregation in current period. If such a record exists we know that
      # previous aggregation and previous maximum aggregation are stored there. Fetching these values
      # would help us in pay in advance value calculation without iterating through all events in current period
      def find_cached_aggregation(with_from_datetime:, with_to_datetime:, grouped_by: nil)
        query = CachedAggregation
          .where(organization_id: billable_metric.organization_id)
          .where(external_subscription_id: subscription.external_id)
          .where(charge_id: charge.id)
          .from_datetime(with_from_datetime)
          .to_datetime(with_to_datetime)
          .where(grouped_by: grouped_by.presence || {})
          .order(timestamp: :desc, created_at: :desc)

        query = query.where.not(event_transaction_id: event.transaction_id) if event.present?
        query = query.where(charge_filter_id: charge_filter.id) if charge_filter

        query.first
      end

      def apply_rounding(result)
        return if billable_metric.rounding_function.blank?
        return if event.present? # Rouding does not apply to the in advance billing

        result.aggregation = BillableMetrics::Aggregations::ApplyRoundingService
          .call(billable_metric:, units: result.aggregation)
          .units

        if result.full_units_number.present?
          result.full_units_number = BillableMetrics::Aggregations::ApplyRoundingService
            .call(billable_metric:, units: result.full_units_number)
            .units
        end

        if result.current_usage_units.present?
          result.current_usage_units = BillableMetrics::Aggregations::ApplyRoundingService
            .call(billable_metric:, units: result.current_usage_units)
            .units
        end
      end
    end
  end
end
