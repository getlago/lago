CREATE TABLE default.events_dead_letter
(
    `organization_id` String,
    `external_subscription_id` String,
    `code` String,
    `transaction_id` String,
    `timestamp` DateTime64(3),
    `ingested_at` DateTime64(3),
    `failed_at` DateTime64(3),
    `event` JSON,
    `initial_error_message` String,
    `error_code` String,
    `error_message` String
)
ENGINE = SharedMergeTree('/clickhouse/tables/{uuid}/{shard}', '{replica}')
ORDER BY (organization_id, external_subscription_id, code, transaction_id, timestamp, ingested_at)
SETTINGS index_granularity = 8192
