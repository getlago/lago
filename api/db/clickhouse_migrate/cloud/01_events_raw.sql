CREATE TABLE default.events_raw
(
    `organization_id` String,
    `external_customer_id` String,
    `external_subscription_id` String,
    `transaction_id` String,
    `timestamp` DateTime64(3),
    `code` String,
    `properties` Map(String, String),
    `ingested_at` DateTime(3),
    `precise_total_amount_cents` Nullable(Decimal(40, 15))
)
ENGINE = SharedMergeTree('/clickhouse/tables/{uuid}/{shard}', '{replica}')
ORDER BY (organization_id, external_subscription_id, code, transaction_id, timestamp)
SETTINGS index_granularity = 8192
