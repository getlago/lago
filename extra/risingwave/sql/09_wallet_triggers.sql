-- Wallet refresh triggers: one Kafka message per usage-row change, keyed by
-- (organization_id, customer_id).
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
CREATE SINK IF NOT EXISTS wallet_refresh_triggers_sink AS
SELECT
    organization_id,
    customer_id,
    COALESCE(target_wallet_code, '') AS target_wallet_code,
    subscription_id,
    code,
    last_ingested_at
FROM usage_realtime
WHERE customer_id IS NOT NULL
  AND billing_period_id IS NOT NULL
-- FORMAT UPSERT (not force_append_only): usage rows UPDATE in place when a
-- key receives more events, and append-only sinks silently drop updates —
-- the trigger must fire on every change. Retractions become tombstones
-- (null payloads); the consumer skips them.
WITH (
    connector = 'kafka',
    topic = 'wallet_refresh_triggers',
    properties.bootstrap.server = 'redpanda:9092',
    primary_key = 'organization_id,customer_id'
) FORMAT UPSERT ENCODE JSON;
