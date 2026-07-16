CREATE TABLE default.api_logs
(
    `request_id` String,
    `organization_id` String,
    `api_key_id` String,
    `api_version` String,
    `client` String,
    `request_body` Map(String, String),
    `request_response` Map(String, Nullable(String)),
    `request_path` String,
    `request_origin` String,
    `http_method` Enum8('get' = 1, 'post' = 2, 'put' = 3, 'delete' = 4),
    `http_status` UInt32,
    `logged_at` DateTime64(3),
    `created_at` DateTime64(3)
)
ENGINE = SharedMergeTree('/clickhouse/tables/{uuid}/{shard}', '{replica}')
PRIMARY KEY (organization_id, api_key_id, request_id, logged_at)
ORDER BY (organization_id, api_key_id, request_id, logged_at)
SETTINGS index_granularity = 8192
