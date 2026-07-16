CREATE TABLE default.activity_logs
(
    `organization_id` String,
    `user_id` Nullable(String),
    `api_key_id` Nullable(String),
    `external_customer_id` Nullable(String),
    `external_subscription_id` Nullable(String),
    `activity_id` String,
    `activity_type` String,
    `activity_source` Enum8('api' = 1, 'front' = 2, 'system' = 3),
    `activity_object` Map(String, Nullable(String)),
    `activity_object_changes` Map(String, Nullable(String)),
    `resource_id` String,
    `resource_type` String,
    `logged_at` DateTime64(3),
    `created_at` DateTime64(3)
)
ENGINE = SharedMergeTree('/clickhouse/tables/{uuid}/{shard}', '{replica}')
PRIMARY KEY (organization_id, activity_type, activity_id, logged_at)
ORDER BY (organization_id, activity_type, activity_id, logged_at)
SETTINGS index_granularity = 8192
