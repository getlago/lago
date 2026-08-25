-- Realtime usage on 15-minute buckets of the event timestamp, written by the
-- RisingWave pipeline (sql/05_usage.sql -> usage_buckets_clickhouse_sink in
-- sql/06_sinks.sql) through a ClickHouse UPSERT sink. The API serves current
-- usage and wallet refresh by summing buckets over the billing-period window
-- Rails computes at read time — 15 minutes is the granularity that makes any
-- timezone's day boundary land on a bucket wall (every real UTC offset is a
-- multiple of 15 minutes).
--
-- RisingWave writes is_deleted (its upsert protocol requires the column);
-- ver is stamped at insert so ReplacingMergeTree keeps the newest version per
-- key. Query with FINAL for exact reads.
--
-- Partitioned by month of the bucket: merges stay inside one month and
-- retention is a DROP PARTITION instead of a TTL mutation.
--
-- DUPLICATED DDL — keep in sync with the Rails ClickHouse migration, which is
-- the source of truth for prod:
--   api/db/clickhouse_migrate/20260821165440_create_usage_buckets15m.rb
--   api/db/clickhouse_migrate/cloud/10_usage_buckets_15m.sql
-- It lives here as well so `setup.sh` can bring up the RisingWave stack on a
-- checkout where `db:clickhouse:migrate` has not run yet: the sink validates
-- its target table at CREATE time and fails without it. Both definitions are
-- CREATE TABLE IF NOT EXISTS, so whichever runs first the other is a no-op.
CREATE TABLE IF NOT EXISTS default.usage_buckets_15m
(
    bucket DateTime64(3),
    organization_id String,
    subscription_id String,
    customer_id String,
    plan_id Nullable(String),
    code String,
    target_wallet_code Nullable(String),
    charge_id String,
    charge_filter_id String,
    grouped_by String,
    aggregation_type String,
    events_count Int64,
    units Decimal(38, 26),
    last_event_at DateTime64(3),
    last_ingested_at DateTime64(3),
    is_deleted UInt8 DEFAULT 0,
    ver DateTime64(3) MATERIALIZED now64(3)
)
ENGINE = ReplacingMergeTree(ver, is_deleted)
PARTITION BY toYYYYMM(bucket)
ORDER BY (organization_id, subscription_id, charge_id, charge_filter_id, grouped_by, bucket);
