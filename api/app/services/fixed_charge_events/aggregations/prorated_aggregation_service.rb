# frozen_string_literal: true

module FixedChargeEvents
  module Aggregations
    class ProratedAggregationService < BaseService
      PerEventAggregationResult = BaseResult[:event_aggregation, :event_prorated_aggregation]

      def call
        sql = ActiveRecord::Base.sanitize_sql_for_conditions(
          [
            prorated_query,
            {
              from_datetime:,
              to_datetime:,
              to_datetime_excluded: to_datetime + 1.day,
              timezone: customer.applicable_timezone
            }
          ]
        )
        sql_result = ActiveRecord::Base.connection.select_one(sql)
        result.aggregation = sql_result["aggregation"]
        result.full_units_number = events_in_range.last.try(:units) || 0
        result
      end

      # we need this for prorated charge_model to be correctly applied
      def per_event_aggregation(grouped_by_values: nil)
        prorated_units_count = result.aggregation
        full_units_count = result.full_units_number
        PerEventAggregationResult.new.tap do |result|
          result.event_aggregation = [full_units_count]
          result.event_prorated_aggregation = [prorated_units_count]
        end
      end

      private

      # in this query we:
      # 1. select event's created at, event's timestamp, event's units for all events with timestamp in this period +
      # last event that was created before the period with timestamp before the period
      # (so the one that was "active" before first event IN this billing_period) with fixed_charge_events_cte_sql
      # 2. then we filter out events, that were created "for later" - Event1: created_at: 05.01, timestamp: 01.02,
      # but can be ignored because of events, created after: Event2: created_at: 20.01, timestamp: 20.01.
      # 3. for each event we calculate weighted_units = units * period_ratio, where period_ratio is
      # how long this event was "effective" in this period comparing to the full duration of the period.
      # 4. we sum up all weighted_units to get the final aggregation.
      def prorated_query
        <<-SQL
          #{fixed_charge_events_cte_sql},
          fixed_charge_events_ignored AS (
            SELECT * FROM (
              SELECT *,
                CASE WHEN #{later_event_earlier_timestamp_sql} THEN true ELSE false END as is_ignored_event
              FROM fixed_charge_events_data
            ) cumulated_ratios
            WHERE is_ignored_event = false
          )

          SELECT COALESCE(SUM(weighted_units), 0) AS aggregation
          FROM (
            SELECT CASE WHEN (#{period_ratio_sql} * units) < 0 THEN 0 ELSE ROUND(#{period_ratio_sql} * units, 6) END AS weighted_units
            FROM fixed_charge_events_ignored
          ) cumulated_ratios
        SQL
      end

      # this query is used to debug the prorated aggregation. instead of returning sum of weighted units for all events,
      # it returns for each event: the weighted units, start date of this event being "effective" and end date of this period, also units.
      def debug_query
        <<-SQL
          #{fixed_charge_events_cte_sql},
          fixed_charge_events_ignored AS (
            SELECT * FROM (
              SELECT *,
                CASE WHEN #{later_event_earlier_timestamp_sql} THEN true ELSE false END as is_ignored_event
              FROM fixed_charge_events_data
            ) cumulated_ratios
            WHERE is_ignored_event = false
          )

          SELECT weighted_units, period_start, period_end, units
          FROM (
            SELECT CASE WHEN (#{period_ratio_sql} * units) < 0 THEN 0 ELSE (#{period_ratio_sql} * units) END AS weighted_units,
              #{period_start} AS period_start,
              #{period_end} AS period_end,
              units
            FROM fixed_charge_events_ignored
          ) cumulated_ratios
        SQL
      end

      def fixed_charge_events_cte_sql
        # NOTE: Common table expression returning event's timestamp, units
        <<-SQL
          WITH fixed_charge_events_data AS (#{
            events_in_range
              .select(
                "timestamp, \
                created_at, \
                units"
              ).to_sql
          })
        SQL
      end

      def later_event_earlier_timestamp_sql
        <<-SQL
          (
            SELECT
              1
            FROM fixed_charge_events_data next_event
            WHERE next_event.timestamp < fixed_charge_events_data.timestamp
              AND next_event.created_at > fixed_charge_events_data.created_at
            LIMIT 1
          ) = 1
        SQL
      end

      def period_ratio_sql
        <<-SQL
          (
            (
              -- define the end of the period
              #{period_end}
              -- define the start of the period
              - #{period_start}
            )::numeric
          )
          /
          -- NOTE: full duration of the period
          #{charges_duration || 1}::numeric
        SQL
      end

      def period_end
        <<-SQL
          DATE((
            -- NOTE: if following event is older than the start of the period, we use the start of the period as the reference
            CASE WHEN (LEAD(timestamp, 1, :to_datetime_excluded) OVER (ORDER BY created_at)) < :from_datetime
            THEN :from_datetime
            ELSE LEAD(timestamp, 1, :to_datetime_excluded ) OVER (ORDER BY created_at)
            END
          )::timestamptz AT TIME ZONE :timezone)
        SQL
      end

      def period_start
        <<-SQL
          DATE((
            -- NOTE: if events is older than the start of the period, we use the start of the period as the reference
            CASE WHEN timestamp < :from_datetime THEN :from_datetime ELSE timestamp END
          )::timestamptz AT TIME ZONE :timezone)
        SQL
      end
    end
  end
end
