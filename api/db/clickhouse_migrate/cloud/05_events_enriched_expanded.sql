SET enable_json_type = 1;

CREATE TABLE events_enriched_expanded
(
    `organization_id` String,
    `external_subscription_id` String,
    `code` String,
    `timestamp` DateTime64(3),
    `transaction_id` String,
    `properties` JSON,
    `sorted_properties` Map(String, String) DEFAULT mapSort(JSONExtract(CAST(properties, 'String'), 'Map(String, String)')),
    `value` Nullable(String),
    `decimal_value` Nullable(Decimal(38, 26)) DEFAULT toDecimal128OrZero(value, 26),
    `enriched_at` DateTime64(3) DEFAULT now(),
    `precise_total_amount_cents` Nullable(Decimal(40, 15)),
    `subscription_id` String DEFAULT '',
    `plan_id` String DEFAULT '',
    `charge_id` String DEFAULT '',
    `charge_version` Nullable(DateTime),
    `charge_filter_id` String DEFAULT '',
    `charge_filter_version` Nullable(DateTime),
    `aggregation_type` String,
    `grouped_by` JSON,
    `sorted_grouped_by` Map(String, String) DEFAULT mapSort(JSONExtract(CAST(grouped_by, 'String'), 'Map(String, String)'))
)
ENGINE = SharedMergeTree('/clickhouse/tables/{uuid}/{shard}', '{replica}')
PRIMARY KEY (organization_id, code, external_subscription_id, charge_id, charge_filter_id, toDate(timestamp))
ORDER BY (organization_id, code, external_subscription_id, charge_id, charge_filter_id, toDate(timestamp), timestamp, transaction_id)
SETTINGS index_granularity = 8192
