# frozen_string_literal: false

class CreateEventsAggregatedMv < ActiveRecord::Migration[8.0]
  def change
    sql = <<-SQL
      SELECT
        organization_id,
        code,
        toStartOfMinute(timestamp) AS started_at,
        external_subscription_id,
        subscription_id,
        plan_id,
        charge_id,
        charge_filter_id,
        toJSONString(sorted_grouped_by) as grouped_by,
        -- Aggregate states based on aggregation type
        sumState(coalesce(precise_total_amount_cents, toDecimal128(0, 15))) AS precise_total_amount_cents_sum_state,
        if(aggregation_type = 'sum', sumState(coalesce(decimal_value, 0)), sumState(toDecimal128(0, 26))) AS sum_state,
        if(aggregation_type = 'count', countState(), countStateIf(false)) AS count_state,
        if(aggregation_type = 'max', maxState(coalesce(decimal_value, 0)), maxState(toDecimal128(0, 26))) AS max_state,
        if(aggregation_type = 'latest', argMaxState(coalesce(decimal_value, 0), timestamp), argMaxState(toDecimal128(0, 26), toDateTime64('1970-01-01', 3))) AS latest_state
      FROM events_enriched_expanded
      WHERE decimal_value IS NOT NULL
        AND subscription_id IS NOT NULL
        AND plan_id IS NOT NULL
        AND charge_id <> ''
      GROUP BY
        organization_id,
        code,
        toStartOfMinute(timestamp),
        external_subscription_id,
        subscription_id,
        plan_id,
        charge_id,
        charge_filter_id,
        sorted_grouped_by,
        aggregation_type
    SQL

    create_view :events_aggregated_mv, materialized: true, as: sql, to: "events_aggregated"
  end
end
