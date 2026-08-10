-- Wallet refresh triggers: one Kafka message per enriched event, keyed by
-- (organization_id, customer_id). Coalescing and wallet-filtering are the
-- CONSUMER's job (batch-collapse in WalletRefreshTriggersConsumer with a
-- large max_messages so collapse scales with backlog).
--
-- Sourced from events_expanded (per event) DELIBERATELY, and kept free of
-- any stateful operator. Both attempted RW-side refinements reintroduce the
-- trailing-flush buffer (an isolated event's trigger is held 18s+ until new
-- data flows — measured 2026-08-10, v3.0.2):
--  * coalescing via streaming dedup (ROW_NUMBER()=1 per customer+second):
--    events_expanded is an UPDATING MV (reprocess corrections update rows),
--    so the planner picks retractable StreamGroupTopN, and its output through
--    the force-append-only conversion buffers the trailing per-key change;
--  * wallet filter via temporal join on a CDC'd wallets table: planned as a
--    non-append-only temporal join — same buffering class.
--  * TUMBLE + EMIT ON WINDOW CLOSE is also out: needs a watermark the source
--    cascade doesn't carry, and an idle stream never closes the last window.
-- A bare projection+filter over events_expanded emits within milliseconds,
-- which is what wallet freshness needs. Kafka absorbs the message rate.
--
-- The key choice is deliberate: Customers::RefreshWalletsService refreshes
-- ALL of a customer's wallets together (the allocation cascade makes them
-- interdependent), so the customer is the serialization unit. Keying by
-- customer guarantees all triggers for one customer land on the same Kafka
-- partition and are consumed sequentially — no two concurrent refreshes for
-- the same customer, hence no PG row-lock contention on its wallet rows.
--
-- target_wallet_code travels in the payload (events can target a wallet via
-- properties.target_wallet_code); the consumer uses it to validate/scope
-- intent, while the refresh itself still covers every wallet of the customer.
--
-- last_ingested_at is the event's ingestion watermark: the consumer waits
-- for usage_realtime_projections to reach it before refreshing (the Kafka
-- trigger otherwise races the Postgres projection sink of the same epoch).
--
-- Known trade-off of force_append_only here: reprocessed events (updates in
-- events_expanded) do not re-trigger a refresh; corrections are picked up by
-- the next event or the reconciliation sweep.
CREATE SINK IF NOT EXISTS wallet_refresh_triggers_sink AS
SELECT
    organization_id,
    customer_id,
    COALESCE(target_wallet_code, '') AS target_wallet_code,
    subscription_id,
    code,
    ingested_at AS last_ingested_at
FROM events_expanded
WHERE customer_id IS NOT NULL
  AND billing_period_id IS NOT NULL
  AND charge_id IS NOT NULL
  AND aggregation_type_code IN (0, 1) -- count, sum: what usage_realtime serves
WITH (
    connector = 'kafka',
    topic = 'wallet_refresh_triggers',
    properties.bootstrap.server = 'redpanda:9092',
    primary_key = 'organization_id,customer_id'
) FORMAT PLAIN ENCODE JSON (force_append_only = 'true');
