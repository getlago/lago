CREATE TABLE default.events_dead_letter_queue
(
    `failed_at` DateTime64(3),
    `event` JSON,
    `initial_error_message` String,
    `error_code` String,
    `error_message` String
)
ENGINE = SharedMergeTree('/clickhouse/tables/{uuid}/{shard}', '{replica}')
ORDER BY (failed_at, initial_error_message, error_code, error_message)
SETTINGS index_granularity = 8192
