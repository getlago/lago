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
        WHERE e.kafka_timestamp > now() - INTERVAL '32 days'
    ) joined
) deduped
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
    target_wallet_code VARCHAR
) APPEND ONLY WITH (retention_seconds = 2851200); -- 33 days

-- Stage 1+2 load: temporal joins against the *current* state of the CDC
-- tables at event arrival time (same semantics as the Go processor reading
-- its cache; LEFT joins match equality keys only, time-window validity is
-- computed as flags and resolved by ranking), then pick the best
-- subscription per event and the best-matching filter per (event, charge)
-- with default-bucket fallback.
--
-- The 32-day filter re-enters here (on the carried kafka_timestamp) so the
-- ranking state is also swept by expiry retractions; the sink drops them.
-- Stage 0 guarantees exactly one input row per unique event, so ranking
-- only resolves the dimension fan-out. The DENSE_RANK ordering fully
-- determines a subscription: valid first, most recent as tie-breakers
-- (mirrors the Go FetchSubscription ordering).
CREATE SINK IF NOT EXISTS events_expanded_load INTO events_expanded AS
WITH joined AS (
    SELECT
        e.*,
        s.id AS subscription_id,
        s.customer_id AS subscription_customer_id,
        s.plan_id AS subscription_plan_id,
        s.started_at AS subscription_started_at,
        s.terminated_at AS subscription_terminated_at,
        (
            s.id IS NOT NULL
            AND s.started_at <= e.event_time
            AND (
                s.terminated_at IS NULL
                OR s.terminated_at >= e.event_time
            )
        ) AS subscription_valid,
        ff.charge_id,
        ff.charge_updated_at,
        ff.charge_filter_id,
        ff.charge_filter_key,
        ff.charge_filter_updated_at,
        ff.filters,
        ff.pricing_group_keys,
        ff.pay_in_advance,
        ff.accepts_target_wallet,
        CASE WHEN ff.charge_id IS NULL THEN NULL
             ELSE filter_match_score(ff.filters, e.properties)
        END AS match_score
    FROM events_enriched e
    LEFT JOIN subscriptions FOR SYSTEM_TIME AS OF PROCTIME() s
        ON s.organization_id = e.organization_id
       AND s.external_id = e.external_subscription_id
    LEFT JOIN flat_filters FOR SYSTEM_TIME AS OF PROCTIME() ff
        ON ff.organization_id = e.organization_id
       AND ff.plan_id = s.plan_id
       AND ff.billable_metric_code = e.code
    WHERE e.kafka_timestamp > now() - INTERVAL '32 days'
),
best_sub AS (
    SELECT * FROM (
        SELECT
            *,
            DENSE_RANK() OVER (
                PARTITION BY organization_id, transaction_id
                ORDER BY
                    subscription_valid DESC,
                    subscription_terminated_at DESC NULLS FIRST,
                    subscription_started_at DESC,
                    subscription_id
            ) AS sub_rank
        FROM joined
    ) ranked_subs
    WHERE sub_rank = 1
),
best_filter AS (
    SELECT * FROM (
        SELECT
            *,
            ROW_NUMBER() OVER (
                PARTITION BY organization_id, transaction_id, COALESCE(charge_id, '')
                ORDER BY match_score DESC, charge_filter_key
            ) AS filter_rank
        FROM best_sub
    ) ranked_filters
    WHERE filter_rank = 1
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
    CASE WHEN subscription_valid THEN subscription_id END AS subscription_id,
    CASE WHEN subscription_valid THEN subscription_customer_id END AS customer_id,
    CASE WHEN subscription_valid THEN subscription_plan_id END AS plan_id,
    charge_id,
    charge_updated_at,
    -- Default bucket: best candidate did not match -> attribute to the charge
    -- itself, without a filter (mirrors MatchingFilter/ToDefaultFilter).
    CASE WHEN COALESCE(match_score, -1) >= 0 THEN charge_filter_id END AS charge_filter_id,
    CASE WHEN COALESCE(match_score, -1) >= 0 THEN charge_filter_updated_at END AS charge_filter_updated_at,
    CASE WHEN COALESCE(match_score, -1) >= 0 THEN filters END AS filters,
    pay_in_advance,
    -- NOTE: custom expression evaluation (billable_metrics.expression) is not
    -- applied yet — phase 2 ships it as a WASM UDF built from lago-expression.
    CASE WHEN aggregation_type_code = 0 THEN '1'
         ELSE properties ->> field_name
    END AS value,
    extract_grouped_by(pricing_group_keys, properties, COALESCE(accepts_target_wallet, false)) AS grouped_by,
    CASE WHEN COALESCE(accepts_target_wallet, false) THEN properties ->> 'target_wallet_code' END AS target_wallet_code
FROM best_filter
WITH (type = 'append-only', force_append_only = 'true');
