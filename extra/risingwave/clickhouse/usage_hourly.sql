-- Serving table for hourly usage history (customer dashboards / analytics).
-- Fed by RisingWave's usage_hourly sink as upserts. RisingWave writes
-- is_deleted (required by its upsert protocol); ver is stamped at insert so
-- ReplacingMergeTree keeps the newest version per key. Query with FINAL
-- (or argMax) for exact reads.
CREATE TABLE IF NOT EXISTS default.usage_hourly (
    hour DateTime64(3),
    organization_id String,
    subscription_id String,
    plan_id Nullable(String),
    code String,
    charge_id String,
    charge_filter_id String,
    grouped_by String,
    aggregation_type String,
    events_count Int64,
    units Decimal(38, 26),
    is_deleted UInt8 DEFAULT 0,
    ver DateTime64(3) MATERIALIZED now64(3)
) ENGINE = ReplacingMergeTree(ver, is_deleted)
ORDER BY (organization_id, subscription_id, charge_id, charge_filter_id, grouped_by, hour);
