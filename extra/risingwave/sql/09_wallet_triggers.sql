-- Wallet refresh triggers: at most one Kafka message per customer per
-- second, keyed by (organization_id, customer_id).
--
-- v2 (post load test): the per-event variant emitted one trigger per
-- enriched event; at 500 ev/s the Ruby consumer (inline refresh) lagged
-- ~100k messages. Two changes cut trigger volume ~25x at load-test shape:
--
--  1. COALESCE: streaming dedup (ROW_NUMBER = 1) on (customer_id, 1s
--     bucket of ingested_at). The FIRST event of each customer-second
--     emits immediately — unlike EMIT ON WINDOW CLOSE there is no
--     watermark wait and no idle-stall (an idle stream would keep the
--     last window open forever, recreating the trailing-edge problem).
--     Later events in the same second are dropped; their usage is still
--     read by the refresh (the consumer reads projections at refresh
--     time, the watermark is only a lower bound) or swept up by the next
--     second's trigger / reconciliation.
--  2. WALLET FILTER: temporal join against the CDC'd wallets table
--     (index wallets_by_customer) — customers without an active wallet
--     (status 0) produce no trigger at all. Temporal join on purpose:
--     no retro-triggering of old events when a wallet is created, and no
--     LHS join state.
--
-- The key choice is deliberate: Customers::RefreshWalletsService refreshes
-- ALL of a customer's wallets together (the allocation cascade makes them
-- interdependent), so the customer is the serialization unit. Keying by
-- customer guarantees all triggers for one customer land on the same Kafka
-- partition and are consumed sequentially — no two concurrent refreshes for
-- the same customer, hence no PG row-lock contention on its wallet rows.
--
-- target_wallet_code travels in the payload; with dedup only the first
-- event of the second contributes its code — acceptable, the refresh
-- covers every wallet of the customer regardless.
--
-- last_ingested_at is the event's ingestion watermark: the consumer waits
-- for usage_realtime_projections to reach it before refreshing (the Kafka
-- trigger otherwise races the Postgres projection sink of the same epoch).
--
-- Known trade-offs:
--  * force_append_only: reprocessed events (updates in events_expanded) do
--    not re-trigger a refresh; corrections are picked up by the next event
--    or the reconciliation sweep. Rare out-of-order arrivals inside one
--    second may emit an extra message (harmless, consumer coalesces).
--  * Dedup state grows by one tiny row per (customer, active second) with
--    no watermark to clean it — bounded cleanup belongs to the state-TTL
--    hardening item (ROADMAP #1).
CREATE SINK IF NOT EXISTS wallet_refresh_triggers_sink AS
SELECT
    organization_id,
    customer_id,
    target_wallet_code,
    subscription_id,
    code,
    last_ingested_at
FROM (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id, trigger_bucket
            ORDER BY last_ingested_at
        ) AS rn
    FROM (
        SELECT
            e.organization_id,
            e.customer_id,
            COALESCE(e.target_wallet_code, '') AS target_wallet_code,
            e.subscription_id,
            e.code,
            e.ingested_at AS last_ingested_at,
            date_trunc('second', e.ingested_at) AS trigger_bucket
        FROM events_expanded AS e
        JOIN wallets FOR SYSTEM_TIME AS OF PROCTIME() AS w
            ON e.customer_id = w.customer_id
        WHERE w.status = 0
          AND e.customer_id IS NOT NULL
          AND e.billing_period_id IS NOT NULL
          AND e.charge_id IS NOT NULL
          AND e.aggregation_type_code IN (0, 1) -- count, sum: what usage_realtime serves
    ) enriched
) deduped
WHERE rn = 1
WITH (
    connector = 'kafka',
    topic = 'wallet_refresh_triggers',
    properties.bootstrap.server = 'redpanda:9092',
    primary_key = 'organization_id,customer_id'
) FORMAT PLAIN ENCODE JSON (force_append_only = 'true');
