CREATE TABLE default.events_enriched
(
    `organization_id` String,
    `external_subscription_id` String,
    `code` String,
    `timestamp` DateTime64(3),
    `transaction_id` String,
    `properties` Map(String, String),
    `sorted_properties` Map(String, String) DEFAULT mapSort(properties),
    `enriched_at` DateTime64(3) DEFAULT now(),
    `value` Nullable(String),
    `decimal_value` Nullable(Decimal(38, 26)) DEFAULT toDecimal128OrZero(value, 26),
    `precise_total_amount_cents` Nullable(Decimal(40, 15))
)
ENGINE = SharedReplacingMergeTree('/clickhouse/tables/{uuid}/{shard}', '{replica}', timestamp)
PRIMARY KEY (organization_id, code, external_subscription_id, toDate(timestamp))
ORDER BY (organization_id, code, external_subscription_id, toDate(timestamp), timestamp, transaction_id)
SETTINGS index_granularity = 8192
