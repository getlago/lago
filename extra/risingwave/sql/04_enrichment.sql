-- Streaming jobs created below default to ADAPTIVE parallelism (use all
-- cores, rescale automatically on tier changes) instead of being pinned to
-- the core count at creation time. Session-scoped: every file sets it because
-- setup.sh/migrate.sh apply each file in its own psql session.
SET streaming_parallelism = ADAPTIVE;

-- Event enrichment: bounded 32-day working set in RisingWave, full history
-- in ClickHouse.
--
-- Topology (Jeremy's design, measured viable 2026-08-21): each stage is a
-- bounded streaming query sinking `force_append_only` INTO an APPEND ONLY
-- TABLE. The table is a RETRACTION FIREWALL, not an archive: the stage's
-- 32-day temporal filter emits expiry DELETEs that sweep the stage's own
-- operator state clean (dedup, ranking, join memos — retraction-driven
-- cleanup), and the force_append_only sink drops those DELETEs so nothing
-- downstream ever sees them. Table `retention_seconds` (33 days) then
-- physically reclaims old rows WITHOUT emitting changelog events (verified
-- by canary: a counting MV over a retention table never decrements).
-- Result: every event-derived store in RisingWave is bounded to ~32-33
-- days; ClickHouse keeps forever-history (events_enriched_rw_shadow,
-- usage_buckets_15m).
--
-- Latency: sink-into-table delivers in ~130ms (isolated event) / ~320ms
-- (after 60s of total silence) — the 18-90s trailing-flush buffering class
-- is Kafka-sink-specific and does NOT apply to internal-table sinks
-- (measured 2026-08-21, falsifying the 2026-08-20 rejection).
--
-- Window semantics: dedup key = the production ReplacingMergeTree key
-- (org, code, external_subscription_id, timestamp, transaction_id), first
-- ingestion wins, answered over a 32-day window. A re-send of the same
-- transaction_id MORE than 32 days after first ingestion passes dedup and
-- lands as a duplicate row downstream — the agreed window contract. There
-- is deliberately NO in-stream correction path (`source_metadata.reprocess`
-- is not carried); corrections are business objects.

-- Stage 0 firewall table: enriched events, one row per unique event.
-- Column order must match the sink SELECT below.
CREATE TABLE IF NOT EXISTS events_enriched (
    organization_id VARCHAR,
    external_subscription_id VARCHAR,
    transaction_id VARCHAR,
    code VARCHAR,
    properties JSONB,
    precise_total_amount_cents VARCHAR,
    source VARCHAR,
    event_ts DOUBLE PRECISION,
    event_time TIMESTAMP,
    ingested_at TIMESTAMP,
    api_post_processed BOOLEAN,
    billable_metric_id VARCHAR,
    aggregation_type_code INT,
    field_name VARCHAR,
    expression VARCHAR,
    recurring BOOLEAN,
    -- Clocks: kafka_timestamp is the broker append time (the only
    -- trustworthy per-event clock, drives the 32-day windows downstream);
    -- rw_received_at is proctime() at the source, barrier-aligned (up to
    -- one barrier interval early) — latency instrumentation only.
    kafka_timestamp TIMESTAMPTZ,
    rw_received_at TIMESTAMPTZ
) APPEND ONLY WITH (retention_seconds = 2851200); -- 33 days

-- Stage 0 load: billable-metric temporal join (INNER: a missing/deleted BM
-- dead-letters the event in the Go processor, so no enriched row) → 32-day
-- window → first-wins dedup on the prod RMT key. The dedup plans as
-- GroupTopN behind the watermark-cleaned dynamic filter: expiry retractions
-- delete its state entries, so "is this event already ingested?" is
-- answered with ≤32 days of state.
CREATE SINK IF NOT EXISTS events_enriched_load INTO events_enriched AS
SELECT
    organization_id,
    external_subscription_id,
    transaction_id,
    code,
    properties,
    precise_total_amount_cents,
    source,
    event_ts,
    event_time,
    ingested_at,
    api_post_processed,
    billable_metric_id,
    aggregation_type_code,
    field_name,
    expression,
    recurring,
    kafka_timestamp,
    rw_received_at
FROM (
    SELECT DISTINCT ON (organization_id, code, external_subscription_id, event_ts, transaction_id)
        *
    FROM (
        SELECT
            e.organization_id,
            e.external_subscription_id,
            e.transaction_id,
            e.code,
            e.properties,
            e.precise_total_amount_cents,
            e.source,
            e."timestamp"::DOUBLE PRECISION AS event_ts,
            to_timestamp(e."timestamp"::DOUBLE PRECISION) AT TIME ZONE 'UTC' AS event_time,
            e.ingested_at,
            COALESCE((e.source_metadata).api_post_processed, false) AS api_post_processed,
            bm.id AS billable_metric_id,
            bm.aggregation_type AS aggregation_type_code,
            bm.field_name,
            bm.expression,
            bm.recurring,
            e.kafka_timestamp,
            e.rw_received_at
        FROM events_raw e
        JOIN billable_metrics FOR SYSTEM_TIME AS OF PROCTIME() bm
            ON bm.organization_id = e.organization_id
           AND bm.code = e.code
           AND bm.deleted_at IS NULL
    ) joined
) deduped
WHERE kafka_timestamp > now() - INTERVAL '32 days'
WITH (type = 'append-only', force_append_only = 'true');

-- Stage 1+2 firewall table: expanded events, one row per (event, charge).
-- Column order must match the sink SELECT below.
CREATE TABLE IF NOT EXISTS events_expanded (
    organization_id VARCHAR,
    external_subscription_id VARCHAR,
    transaction_id VARCHAR,
    code VARCHAR,
    properties JSONB,
    precise_total_amount_cents VARCHAR,
    source VARCHAR,
    event_ts DOUBLE PRECISION,
    event_time TIMESTAMP,
    ingested_at TIMESTAMP,
    api_post_processed BOOLEAN,
    billable_metric_id VARCHAR,
    aggregation_type_code INT,
    aggregation_type VARCHAR,
    recurring BOOLEAN,
    subscription_id VARCHAR,
    customer_id VARCHAR,
    plan_id VARCHAR,
    charge_id VARCHAR,
    charge_updated_at TIMESTAMP,
    charge_filter_id VARCHAR,
    charge_filter_updated_at TIMESTAMP,
    filters JSONB,
    pay_in_advance BOOLEAN,
    value VARCHAR,
    grouped_by JSONB,
    target_wallet_code VARCHAR,
    -- Clocks carried through from stage 0, so the expanded row alone can account
    -- for its own latency: broker append time and the source pickup proctime.
    kafka_timestamp TIMESTAMPTZ,
    rw_received_at TIMESTAMPTZ,
    -- Stage-1+2 stamp, and the reason the sink below lists its target columns
    -- explicitly: the sink does NOT write this one, so the DEFAULT applies at
    -- insert and records when stage 1 actually emitted the row.
    --
    -- It has to be a column DEFAULT. `proctime()` is rejected outside
    -- CREATE TABLE/SOURCE, and a bare `now()` in a streaming projection is
    -- rejected too ("only allowed in WHERE, HAVING, ON and FROM") — a table
    -- default is the one position where RisingWave will evaluate it per row.
    --
    -- CAVEAT, same class as rw_received_at: now() is the BARRIER timestamp, so
    -- rows emitted in one barrier share a stamp and the resolution is
    -- barrier_interval_ms (250ms dev / 1s default). Do not read it below that.
    rw_expanded_at TIMESTAMPTZ DEFAULT now()
) APPEND ONLY WITH (retention_seconds = 2851200); -- 33 days

-- Stage 1+2 load (REDESIGNED 2026-08-28, ROADMAP §0c): two single-row
-- temporal joins + two scalar UDFs, structurally identical to the Go
-- processor (cache lookup + in-memory loop over the candidates).
--
-- The previous encoding resolved the dimension fan-out with a subscription
-- DENSE_RANK and a filter ROW_NUMBER. Same semantics, wildly different cost
-- model: rank/GroupTopN must be able to re-emit a new winner if inputs
-- change, so they materialized every candidate row as operator state per
-- event identity and synced it to object storage EVERY BARRIER — 7 state
-- tables, 244MB memtables, and the ~3k ev/s staging ceiling PROVEN by
-- amputation (5,001 ev/s at 9ms barriers without this job). The Go
-- processor pays a microsecond loop over cached rows for the same decision.
--
-- Now the candidate sets ARE the lookup rows: subscriptions_agg and
-- flat_filters_agg (02_flat_filters.sql) hold one JSONB array per lookup
-- key, and pick_subscription() / matching_filter() (03_functions.sql) are
-- line-by-line ports of the Go FetchSubscription / MatchingFilter loops —
-- parity by PORT, not by re-encoding into SQL operators. Both ranking
-- stages are gone; per-event operator state in this job is ZERO (temporal
-- joins on an append-only LHS keep no LHS state, projections are
-- stateless), which also removes the need for the 32-day temporal filter
-- that existed to sweep the ranking state: there is nothing left to sweep,
-- and entry is already bounded by stage 0's own 32-day filter plus
-- events_enriched's physical retention. (Consequence of dropping it: a
-- stage-1 REBUILD replays events_enriched's full ~33-day retention window
-- instead of 32 days. Nothing else changes.)
--
-- Go-parity notes:
--   * No valid subscription at the event timestamp -> pick_subscription
--     returns NULL -> NULL plan_id joins no charge -> ONE subscription-less,
--     charge-less row. (The ranked encoding instead attributed charges via
--     the invalid subscription's plan while nulling the subscription
--     columns — a divergence from the Go processor, gone with it.)
--   * The recurring-BM fallback (Go retries FetchSubscription at now() for
--     recurring metrics) is still NOT implemented, same as before —
--     tracked in ROADMAP §1; UDFs are pure so it cannot live inside
--     pick_subscription.
--   * matching_filter's inputs are COALESCE'd: WASM UDFs are strict on SQL
--     NULL, while Go accepts nil properties (nil never matches a filter
--     key, same as '{}').
CREATE SINK IF NOT EXISTS events_expanded_load INTO events_expanded (
    organization_id,
    external_subscription_id,
    transaction_id,
    code,
    properties,
    precise_total_amount_cents,
    source,
    event_ts,
    event_time,
    ingested_at,
    api_post_processed,
    billable_metric_id,
    aggregation_type_code,
    aggregation_type,
    recurring,
    subscription_id,
    customer_id,
    plan_id,
    charge_id,
    charge_updated_at,
    charge_filter_id,
    charge_filter_updated_at,
    filters,
    pay_in_advance,
    value,
    grouped_by,
    target_wallet_code,
    kafka_timestamp,
    rw_received_at
) AS
WITH sub_picked AS (
    -- One-row lookup + FetchSubscription port. No subscriptions_agg row or
    -- no valid subscription at event_ts -> picked_sub is SQL NULL.
    SELECT
        e.*,
        pick_subscription(sa.subs, e.event_ts) AS picked_sub
    FROM events_enriched e
    LEFT JOIN subscriptions_agg FOR SYSTEM_TIME AS OF PROCTIME() sa
        ON sa.organization_id = e.organization_id
       AND sa.external_id = e.external_subscription_id
),
sub_resolved AS (
    SELECT
        *,
        picked_sub ->> 'id' AS subscription_id,
        picked_sub ->> 'customer_id' AS customer_id,
        picked_sub ->> 'plan_id' AS plan_id
    FROM sub_picked
),
charged AS (
    -- One row per charge of (org, plan, code) — the charge fan-out is the
    -- OUTPUT cardinality (one expanded row per charge), same as the Go
    -- processor's per-charge loop. matching_filter resolves the charge's
    -- candidate array to the winning filter or the default bucket; keys it
    -- omits (default bucket: filter identity) read back as SQL NULL.
    SELECT
        s.*,
        ffc.charge_id,
        ffc.charge_updated_at,
        ffc.pay_in_advance,
        ffc.accepts_target_wallet,
        CASE WHEN ffc.charge_id IS NULL THEN NULL
             ELSE matching_filter(ffc.filters_agg, COALESCE(s.properties, '{}'::jsonb))
        END AS mf
    FROM sub_resolved s
    LEFT JOIN flat_filters_agg FOR SYSTEM_TIME AS OF PROCTIME() ffc
        ON ffc.organization_id = s.organization_id
       AND ffc.plan_id = s.plan_id
       AND ffc.billable_metric_code = s.code
)
SELECT
    organization_id,
    external_subscription_id,
    transaction_id,
    code,
    properties,
    precise_total_amount_cents,
    source,
    event_ts,
    event_time,
    ingested_at,
    api_post_processed,
    billable_metric_id,
    aggregation_type_code,
    CASE aggregation_type_code
        WHEN 0 THEN 'count'
        WHEN 1 THEN 'sum'
        WHEN 2 THEN 'max'
        WHEN 3 THEN 'unique_count'
        WHEN 5 THEN 'weighted_sum'
        WHEN 6 THEN 'latest'
        WHEN 7 THEN 'custom'
        ELSE ''
    END AS aggregation_type,
    recurring,
    subscription_id,
    customer_id,
    plan_id,
    charge_id,
    charge_updated_at,
    mf ->> 'charge_filter_id' AS charge_filter_id,
    (mf ->> 'charge_filter_updated_at')::timestamp AS charge_filter_updated_at,
    mf -> 'filters' AS filters,
    pay_in_advance,
    -- NOTE: custom expression evaluation (billable_metrics.expression) is not
    -- applied yet — phase 2 ships it as a WASM UDF built from lago-expression.
    CASE WHEN aggregation_type_code = 0 THEN '1'
         ELSE properties ->> field_name
    END AS value,
    extract_grouped_by(
        COALESCE(mf -> 'pricing_group_keys', 'null'::jsonb),
        COALESCE(properties, '{}'::jsonb),
        COALESCE(accepts_target_wallet, false)
    ) AS grouped_by,
    CASE WHEN COALESCE(accepts_target_wallet, false) THEN properties ->> 'target_wallet_code' END AS target_wallet_code,
    kafka_timestamp,
    rw_received_at
FROM charged
WITH (type = 'append-only', force_append_only = 'true');
