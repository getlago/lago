-- Shadow of default.events_enriched_expanded, fed by RisingWave instead of the
-- Go events-processor (see sql/06_sinks.sql). One row per (event, charge) with
-- the best-matching charge filter resolved, i.e. the same grain the production
-- table holds — so parity diffing is a plain SQL join instead of a topic diff.
--
-- Shape mirrors production `events_enriched_expanded` (column names, PRIMARY
-- KEY and ORDER BY identical, so parity queries scan both the same way), with
-- three deliberate departures:
--
--  * Plain MergeTree, NOT ReplacingMergeTree(timestamp). Deduplication happens
--    upstream in RisingWave (stage 0 first-wins dedup on the prod RMT key, and
--    since the 2026-08-23 partition-key fix one rank partition holds exactly
--    one event's fan-out), so this table only ever receives unique rows.
--    Duplicate counting therefore works WITHOUT FINAL — which is the point of
--    a shadow: a duplicate must show up, not get collapsed on read.
--  * properties/grouped_by arrive as Strings, not JSON. The RisingWave
--    ClickHouse sink can only deliver JSONB as a String, so the sink writes
--    `properties_json`/`grouped_by_json` and the Map columns are MATERIALIZED
--    from them. `sorted_properties` and `sorted_grouped_by` keep the
--    production names and mapSort semantics, so those columns compare directly
--    against production rows.
--  * precise_total_amount_cents is Decimal(38, 15), not the production
--    Decimal(40, 15): 40 digits needs Decimal256, which the sink cannot
--    deliver. Same scale, 38 significant digits — far beyond real amounts.
--
-- ingested_at (stamped by the Lago API at ingest, carried through the whole
-- RisingWave pipeline) plus enriched_at (stamped by ClickHouse at insert) make
-- this table the e2e latency instrument that the retired shadow Kafka topic +
-- `pipeline_latency_e2e` loopback used to be — see sql/07_observability.sql.
--
-- RisingWave expires its own state after 32-33 days (events_expanded
-- retention_seconds); ClickHouse keeps the full history (no TTL here).
CREATE TABLE IF NOT EXISTS default.events_enriched_expanded_rw_shadow (
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
    precise_total_amount_cents Nullable(Decimal(38, 15)),
    subscription_id String,
    plan_id String,
    charge_id String,
    charge_version Nullable(DateTime64(3)),
    charge_filter_id String,
    charge_filter_version Nullable(DateTime64(3)),
    aggregation_type String,
    grouped_by_json String,
    grouped_by Map(String, String) MATERIALIZED JSONExtract(grouped_by_json, 'Map(String, String)'),
    sorted_grouped_by Map(String, String) MATERIALIZED mapSort(grouped_by),
    -- Nullable: the event payload's `ingested_at` is not guaranteed by the
    -- topic contract (see sql/05_usage.sql). This column is pure latency
    -- instrumentation, so an absent value must stay absent — substituting a
    -- fake timestamp would silently poison the e2e figures. Non-nullable here
    -- costs a sink crash loop per such event.
    ingested_at Nullable(DateTime64(3)),
    -- RisingWave's own clocks, carried so stage timings are queryable HERE and
    -- not only through the load-test app:
    --   rw_enriched_at = proctime() at the source (stage 0 pickup)
    --   rw_expanded_at = barrier at which stage 1+2 emitted the row
    -- Both are barrier-aligned (resolution = barrier_interval_ms), so
    -- rw_expanded_at - rw_enriched_at is the enrich→expand cost measured on ONE
    -- clock, and enriched_at - rw_expanded_at is the sink+insert cost.
    --
    -- Existing table? ALTER TABLE default.events_enriched_expanded_rw_shadow
    --   ADD COLUMN rw_enriched_at Nullable(DateTime64(3)),
    --   ADD COLUMN rw_expanded_at Nullable(DateTime64(3));
    -- (Nullable so rows written before the columns existed stay readable.)
    rw_enriched_at Nullable(DateTime64(3)),
    rw_expanded_at Nullable(DateTime64(3))
)
ENGINE = MergeTree
PRIMARY KEY (organization_id, code, external_subscription_id, charge_id, charge_filter_id, toDate(timestamp))
ORDER BY (organization_id, code, external_subscription_id, charge_id, charge_filter_id, toDate(timestamp), timestamp, transaction_id)
SETTINGS index_granularity = 8192;
