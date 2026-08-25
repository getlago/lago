CREATE DATABASE IF NOT EXISTS bench;

DROP TABLE IF EXISTS bench.buckets;
CREATE TABLE bench.buckets
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
ORDER BY (organization_id, subscription_id, charge_id, charge_filter_id, grouped_by, bucket);

DROP TABLE IF EXISTS bench.events;
CREATE TABLE bench.events
(
    `organization_id` String,
    `external_subscription_id` String,
    `code` String,
    `timestamp` DateTime64(3),
    `transaction_id` String,
    `properties` Map(String, String),
    `sorted_properties` Map(String, String) DEFAULT mapSort(properties),
    `value` Nullable(String),
    `decimal_value` Nullable(Decimal(38, 26)) DEFAULT toDecimal128OrZero(value, 26),
    `enriched_at` DateTime64(3) DEFAULT now64(3),
    `precise_total_amount_cents` Nullable(Decimal(40, 15))
)
ENGINE = ReplacingMergeTree(timestamp)
PRIMARY KEY (organization_id, code, external_subscription_id, toDate(timestamp))
ORDER BY (organization_id, code, external_subscription_id, toDate(timestamp), timestamp, transaction_id)
SETTINGS index_granularity = 8192;

-- Same shape as bench.buckets, but populated across many orgs with
-- UUID-shaped ids so subscription_id-only filters must probe every org range.
DROP TABLE IF EXISTS bench.buckets_mo;
CREATE TABLE bench.buckets_mo AS bench.buckets;
