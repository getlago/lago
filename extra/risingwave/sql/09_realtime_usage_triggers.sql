-- Streaming jobs created below default to ADAPTIVE parallelism (use all
-- cores, rescale automatically on tier changes) instead of being pinned to
-- the core count at creation time. Session-scoped: every file sets it because
-- setup.sh/migrate.sh apply each file in its own psql session.
SET streaming_parallelism = ADAPTIVE;

-- Wallet refresh triggers: one Kafka message per enriched event, keyed by
-- (organization_id, customer_id). Coalescing and wallet-filtering are the
-- CONSUMER's job (batch-collapse in WalletRefreshConsumer with a
-- large max_messages so collapse scales with backlog).
--
-- Sourced from events_expanded (per event) DELIBERATELY, and kept free of
-- any stateful operator. Both attempted RW-side refinements reintroduce the
-- trailing-flush buffer (an isolated event's trigger is held 18s+ until new
-- data flows — measured 2026-08-10, v3.0.2):
--  * coalescing via streaming dedup (ROW_NUMBER()=1 per customer+second):
--    events_expanded is an UPDATING MV (its ranking stages can retract), so
--    the planner picks retractable StreamGroupTopN, and its output through
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
-- for the ClickHouse usage_buckets_15m table to reach it before refreshing
-- (the Kafka trigger otherwise races the ClickHouse sink of the same epoch).
--
-- force_append_only here: events_expanded no longer emits ranking-flip
-- updates (2026-08-23 partition-key fix, ROADMAP §0) — one rank partition is
-- one event's fan-out. Any update that DID reach this sink would be
-- rewritten UpdateInsert -> Insert, i.e. an extra trigger, which the
-- consumer's per-customer batch collapse absorbs idempotently.
--
-- REBUILD GOTCHA (staging, 2026-08-28): a recreated sink replays the FULL
-- events_expanded snapshot — every retained event becomes a trigger message
-- (millions on a loaded cluster), all garbage work for the consumer. The
-- clean fix, `snapshot = 'false'`, was TRIED and is NOT available here:
-- v3.0.2 only supports it on `CREATE SINK FROM <relation>`, not
-- `AS SELECT`, and hoisting this projection into an MV to sink FROM would
-- materialize unbounded per-event state (append-only-table retention is
-- physical, no changelog — a downstream MV never shrinks; canary-proven
-- 2026-08-21). So after ANY recreation of this sink: seek the
-- `lago_wallet_refresh_consumer` group to the end (consumer
-- stopped), then restart the consumer.
CREATE SINK IF NOT EXISTS realtime_usage_triggers_sink AS
SELECT
    organization_id,
    customer_id,
    COALESCE(target_wallet_code, '') AS target_wallet_code,
    subscription_id,
    code,
    ingested_at AS last_ingested_at
FROM events_expanded
WHERE customer_id IS NOT NULL
  AND charge_id IS NOT NULL
  AND aggregation_type_code IN (0, 1) -- count, sum: what usage_buckets_15m serves
WITH (
    connector = 'kafka',
    topic = 'realtime_usage_triggers',
    properties.bootstrap.server = 'redpanda:9092',
    primary_key = 'organization_id,customer_id'
) FORMAT PLAIN ENCODE JSON (force_append_only = 'true');
