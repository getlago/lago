-- Wallet refresh triggers: one Kafka message per enriched event, keyed by
-- (organization_id, customer_id).
--
-- Sourced from events_expanded (per event) rather than usage_realtime (per
-- usage row) DELIBERATELY: upsert sinks from updating MVs buffer the
-- trailing per-key change and deliver an isolated event 30-90s late, while
-- append-only event emission is milliseconds. Coalescing is the consumer's
-- job anyway (it batch-collapses per customer), and Kafka absorbs the
-- higher message rate.
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
