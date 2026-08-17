-- Shadow of default.events_enriched, fed by RisingWave instead of the Go
-- events-processor (see sql/10_enriched_shadow.sql).
--
-- Plain MergeTree, NOT ReplacingMergeTree: deduplication happens upstream in
-- the RisingWave `events_enriched` MV (first delivery per event wins), so this
-- table only ever receives unique rows and duplicate counting works without
-- FINAL. Same PRIMARY KEY / ORDER BY as the real table so parity queries scan
-- the same way. RisingWave expires its own state after 32 days; ClickHouse
-- keeps the full history (no TTL here).
--
-- The RisingWave ClickHouse sink can only deliver JSONB as a String, so the
-- sink writes `properties_json` and `properties` is MATERIALIZED with the
-- exact expression the production path uses in events_enriched_mv
-- (JSONExtract from the raw JSON string of the Kafka payload).
CREATE TABLE IF NOT EXISTS default.events_enriched_rw_shadow (
    organization_id String,
    external_subscription_id String,
    code String,
    timestamp DateTime64(3),
    transaction_id String,
    properties_json String,
    properties Map(String, String) MATERIALIZED JSONExtract(properties_json, 'Map(String, String)'),
    sorted_properties Map(String, String) MATERIALIZED mapSort(properties),
    value Nullable(String),
    decimal_value Nullable(Decimal(38, 26)) MATERIALIZED toDecimal128OrZero(value, 26),
    enriched_at DateTime64(3) DEFAULT now64(3),
    -- Prod uses Decimal(40,15) (Decimal256), which the RisingWave ClickHouse
    -- sink cannot write. Decimal(38,15) (Decimal128) is lossless here anyway:
    -- RisingWave decimals cap at 28 significant digits.
    precise_total_amount_cents Nullable(Decimal(38, 15)),
    -- Shadow-only: proctime() when RisingWave picked the event up for
    -- enrichment (barrier-aligned: up to one barrier interval early).
    -- enriched_at - rw_ingested_at ~= RW enrichment + sink flush + CH
    -- insert; join events_enriched on transaction_id to compare
    -- enriched_at against the Go path per event.
    rw_ingested_at DateTime64(3)
)
ENGINE = MergeTree
PRIMARY KEY (organization_id, code, external_subscription_id, toDate(timestamp))
ORDER BY (organization_id, code, external_subscription_id, toDate(timestamp), timestamp, transaction_id)
SETTINGS index_granularity = 8192;
