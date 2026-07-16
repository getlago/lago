CREATE TABLE default.security_logs
(
    `organization_id` String,
    `user_id` Nullable(String),
    `api_key_id` Nullable(String),

    `log_id` String,
    `log_type` String,
    `log_event` String,

    `device_info` Map(String, Nullable(String)),
    `resources` Map(String, Nullable(String)),

    `logged_at` DateTime64(3),
    `created_at` DateTime64(3)
)
ENGINE = SharedMergeTree('/clickhouse/tables/{uuid}/{shard}', '{replica}')
PRIMARY KEY (organization_id, log_id, logged_at)
ORDER BY (organization_id, log_id, logged_at)
SETTINGS index_granularity = 8192
