# frozen_string_literal: true

module BillableMetrics
  module Breakdown
    class UniqueCountService < BillableMetrics::ProratedAggregations::UniqueCountService
      Result = BaseResult[:aggregator, :breakdown]

      def breakdown
        breakdown = event_store.prorated_unique_count_breakdown(with_remove: true)
          .group_by { |r| r["property"] }
          .map do |_, rows|
            row = rows.first
            operation_type = row["operation_type"]

            # NOTE: breakdown, is based only on the current period
            datetime = (row["timestamp"] < from_datetime) ? from_datetime : row["timestamp"]

            if rows.count.even? # NOTE: add then remove
              operation_type = (row["timestamp"] < from_datetime) ? "remove" : "add_and_removed"
              datetime = rows.last["timestamp"] unless operation_type == "add_and_removed"
            elsif rows.count > 2
              operation_type = "add"
            end

            Item.new(
              date: datetime.in_time_zone(customer.applicable_timezone).to_date,
              action: operation_type,
              amount: row["prorated_value"].ceil,
              duration: duration(rows),
              total_duration: period_duration
            )
          end

        # NOTE: in the breakdown, dates are in customer timezone
        result.breakdown = breakdown.sort_by(&:date)
        result
      end

      private

      def duration(rows)
        prorated_value = if rows.count > 2
          rows.sum { |h| h["prorated_value"] }
        else
          rows.first["prorated_value"]
        end

        ((to_datetime - from_datetime).fdiv(1.day).round * prorated_value).round
      end
    end
  end
end
