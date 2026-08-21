-- Shadow output: enriched + expanded events, shaped like the Go processor's
-- EnrichedEvent JSON, produced to a shadow topic for parity diffing against
-- events_enriched_expanded.
--
-- force_append_only: the rare retractions events_expanded can emit (a
-- ranking flip while a partition's fan-out rows are still arriving) are
-- dropped — same at-least-once semantics consumers already handle today.
CREATE SINK IF NOT EXISTS events_enriched_expanded_shadow_sink AS
SELECT
    organization_id,
    external_subscription_id,
    subscription_id,
    plan_id,
    transaction_id,
    code,
    aggregation_type,
    properties,
    precise_total_amount_cents,
    source,
    value,
    event_ts AS "timestamp",
    charge_id,
    charge_updated_at,
    charge_filter_id,
    charge_filter_updated_at,
    grouped_by,
    target_wallet_code,
    -- Not part of the Go EnrichedEvent shape; carried for e2e latency
    -- measurement (07_observability.sql). Ignore when parity-diffing.
    ingested_at
FROM events_expanded
WHERE charge_id IS NOT NULL
WITH (
    connector = 'kafka',
    topic = 'events_enriched_expanded_shadow',
    properties.bootstrap.server = 'redpanda:9092',
    primary_key = 'organization_id,transaction_id,charge_id'
) FORMAT PLAIN ENCODE JSON (force_append_only = 'true');

-- Hourly usage history -> ClickHouse (customer dashboards / analytics).
-- Upserts into the ReplacingMergeTree created by clickhouse/usage_hourly.sql;
-- corrections re-emit the affected hour and replace the row version.
CREATE SINK IF NOT EXISTS usage_hourly_clickhouse_sink AS
SELECT
    -- event_time is naive UTC; the ClickHouse sink requires timestamptz.
    hour AT TIME ZONE 'UTC' AS hour,
    organization_id,
    subscription_id,
    plan_id,
    code,
    charge_id,
    charge_filter_id,
    grouped_by,
    aggregation_type,
    events_count,
    units
FROM usage_hourly
WITH (
    connector = 'clickhouse',
    type = 'upsert',
    primary_key = 'organization_id,subscription_id,charge_id,charge_filter_id,grouped_by,hour',
    clickhouse.url = 'http://clickhouse:8123',
    clickhouse.user = 'default',
    clickhouse.password = 'default',
    clickhouse.database = 'default',
    clickhouse.table = 'usage_hourly',
    clickhouse.delete.column = 'is_deleted'
);
