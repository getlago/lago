-- Shadow of the Go processor's *enriched* (non-expanded) output.
--
-- The Go path (processor.go / ProduceEnrichedEvent -> events_enriched topic ->
-- CH events_enriched_mv) emits ONE row per event, with no charge fan-out, and
-- only needs the billable metric: the columns persisted in ClickHouse
-- events_enriched are (org, external_subscription_id, code, timestamp,
-- transaction_id, properties, value, precise_total_amount_cents).
-- Subscription/charge enrichment never reaches that table.
--
-- Faithful semantics mirrored here:
--  * INNER join on billable_metrics: a missing/deleted BM dead-letters the
--    event in Go (FetchBillableMetric not-found is a failure), so no enriched
--    row is produced.
--  * reprocessed events skip the enriched topic (Go only re-emits expanded),
--    hence the NOT reprocess filter.
--  * deduplication lives HERE (not in ClickHouse): the shadow CH table is a
--    plain MergeTree, so duplicate deliveries are collapsed in this MV —
--    first delivery wins, keyed exactly like the production
--    ReplacingMergeTree key (org, code, external_subscription_id, timestamp,
--    transaction_id).
--  * value: '1' for count, else fmt.Sprintf("%v", properties[field_name]) —
--    including Go's quirk of emitting the literal string "<nil>" when the
--    property is absent or JSON null, mirrored so parity diffs stay quiet.
--
-- State retention: events older than 32 days (by Kafka broker arrival time)
-- are expired from this MV by the temporal filter, which also cleans the
-- dedup state. The filter sits AFTER the temporal join (append-only left side
-- required) and BEFORE the dedup (so its state is what gets cleaned). Expiry
-- deletes are dropped at the sink (force_append_only) — ClickHouse keeps the
-- full history.
--
-- Known parity gaps (same as the expanded shadow):
--  * custom expressions (billable_metrics.expression) are not evaluated
--    (phase 2, WASM UDF) — BMs with an expression and source != HTTP_RUBY
--    will diff on value/properties.
--  * Go formats numbers via %v (float64), so exotic cases like 1e+21 render
--    differently than JSONB ->> text extraction.
CREATE MATERIALIZED VIEW IF NOT EXISTS events_enriched AS
WITH joined AS (
    SELECT
        e.organization_id,
        e.external_subscription_id,
        e.code,
        -- already timestamptz; the ClickHouse sink rejects naive timestamps
        to_timestamp(e."timestamp"::DOUBLE PRECISION) AS "timestamp",
        e.transaction_id,
        e.properties::VARCHAR AS properties_json,
        CASE WHEN bm.aggregation_type = 0 THEN '1'
             ELSE COALESCE(e.properties ->> bm.field_name, '<nil>')
        END AS value,
        NULLIF(e.precise_total_amount_cents, '')::DECIMAL AS precise_total_amount_cents,
        e.ingested_at,
        e.kafka_timestamp
    FROM events_raw e
    JOIN billable_metrics FOR SYSTEM_TIME AS OF PROCTIME() bm
        ON bm.organization_id = e.organization_id
       AND bm.code = e.code
       AND bm.deleted_at IS NULL
    WHERE NOT COALESCE((e.source_metadata).reprocess, false)
),
recent AS (
    SELECT * FROM joined
    WHERE kafka_timestamp > now() - INTERVAL '32 days'
)
SELECT
    organization_id,
    external_subscription_id,
    code,
    "timestamp",
    transaction_id,
    properties_json,
    value,
    precise_total_amount_cents,
    -- Not part of the events_enriched shape; kept for latency probes (compare
    -- against enriched_at stamped by ClickHouse at insert). Not sunk.
    ingested_at
FROM (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY organization_id, code, external_subscription_id, "timestamp", transaction_id
            ORDER BY ingested_at
        ) AS delivery_rank
    FROM recent
) deduped
WHERE delivery_rank = 1;

-- Insert-only sink into the plain MergeTree created by
-- clickhouse/events_enriched_rw_shadow.sql. force_append_only drops the
-- retractions the 32-day temporal filter emits on expiry, so ClickHouse
-- retains rows RisingWave has already forgotten. enriched_at, properties
-- (Map), sorted_properties and decimal_value are stamped/derived
-- ClickHouse-side, exactly like the production Kafka-queue path.
CREATE SINK IF NOT EXISTS events_enriched_rw_shadow_sink AS
SELECT
    organization_id,
    external_subscription_id,
    code,
    "timestamp",
    transaction_id,
    properties_json,
    value,
    precise_total_amount_cents
FROM events_enriched
WITH (
    connector = 'clickhouse',
    type = 'append-only',
    force_append_only = 'true',
    clickhouse.url = 'http://clickhouse:8123',
    clickhouse.user = 'default',
    clickhouse.password = 'default',
    clickhouse.database = 'default',
    clickhouse.table = 'events_enriched_rw_shadow'
);
