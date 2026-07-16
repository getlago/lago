# frozen_string_literal: true

module BillableMetrics
  module Breakdown
    class SumService < BillableMetrics::ProratedAggregations::SumService
      Result = BaseResult[:aggregator, :breakdown]

      def breakdown
        breakdown = persisted_breakdown
        breakdown += period_breakdown

        # NOTE: in the breakdown, dates are in customer timezone
        result.breakdown = breakdown.sort_by(&:date)
        result
      end

      private

      def from_date_in_customer_timezone
        from_datetime.in_time_zone(customer.applicable_timezone).to_date
      end

      def to_date_in_customer_timezone
        to_datetime.in_time_zone(customer.applicable_timezone).to_date
      end

      def persisted_breakdown
        event_store = event_store_class.new(
          code: billable_metric.code,
          subscription:,
          boundaries: {to_datetime: from_datetime},
          filters:
        )

        event_store.use_from_boundary = false
        event_store.aggregation_property = billable_metric.field_name
        event_store.numeric_property = true
        persisted_sum = event_store.sum(with_count: false).value
        return [] if persisted_sum.zero?

        [
          Item.new(
            date: from_date_in_customer_timezone,
            action: persisted_sum.negative? ? "remove" : "add",
            amount: persisted_sum,
            duration: (to_date_in_customer_timezone + 1.day - from_date_in_customer_timezone).to_i,
            total_duration: period_duration
          )
        ]
      end

      def period_breakdown
        event_store.sum_date_breakdown.map do |aggregation|
          Item.new(
            date: aggregation[:date],
            action: aggregation[:value].negative? ? "remove" : "add",
            amount: aggregation[:value],
            duration: (to_date_in_customer_timezone + 1.day - aggregation[:date]).to_i,
            total_duration: period_duration
          )
        end
      end
    end
  end
end
