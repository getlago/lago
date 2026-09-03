-- ALTERNATIVE dimension source: Debezium (Kafka Connect) -> Kafka topics ->
-- Flink `upsert-kafka`, instead of Flink's own postgres-cdc connector.
--
-- WHY THIS EXISTS — it removes BOTH of the costs Flink CDC imposes on the
-- production database (ROADMAP Gate 1):
--
--   1. ONE REPLICATION SLOT FOR ALL TABLES. Flink's postgres-cdc connector
--      creates a slot per source table and they CANNOT share one (measured:
--      `ERROR: replication slot "lago_flink_shared" already exists`). One
--      Debezium connector with a `table.include.list` captures all six
--      dimension tables on a single slot — verified.
--
--   2. NO `REPLICA IDENTITY FULL`. upsert-kafka keys on the primary key and
--      treats a null value as a delete, so it never needs a before-image;
--      Flink reconstructs one in ChangelogNormalize. Postgres keeps
--      REPLICA IDENTITY DEFAULT and pays no WAL write amplification.
--
--   3. Bonus: CDC no longer shares the Flink application's lifecycle, so MSF
--      restarts and rescales stop churning replication slots. On AWS this is
--      MSK Connect.
--
-- Cost moved, not removed: ChangelogNormalize holds one entry per dimension
-- row in Flink state. That is bounded by CATALOG SIZE, not event volume —
-- the right side of the trade.
--
-- Requires the Debezium connector to run with the ExtractNewRecordState SMT
-- and `delete.tombstone.handling.mode=tombstone` (see
-- ../../kafka-connect/lago-dimensions-cdc.json), so the topic value is the
-- flat row and a delete is a tombstone.
CREATE TABLE IF NOT EXISTS billable_metrics_k (
    id               STRING,
    organization_id  STRING,
    code             STRING,
    aggregation_type INT,
    recurring        BOOLEAN,
    field_name       STRING,
    expression       STRING,
    -- Debezium `time.precision.mode=connect` renders timestamps as epoch
    -- millis; read as BIGINT and convert where needed rather than fighting
    -- the JSON format's timestamp parsing.
    deleted_at       BIGINT,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector'                    = 'upsert-kafka',
    'topic'                        = '${cdc.topic.prefix}.public.billable_metrics',
    'properties.bootstrap.servers' = '${kafka.bootstrap.servers}',
    'properties.group.id'          = '${kafka.group.id}_dim_bm',
    'key.format'                   = 'json',
    -- NOTE: do NOT set 'value.json.ignore-parse-errors' here. A delete
    -- arrives as a tombstone (null value); with parse errors ignored the
    -- format swallows it and upsert-kafka never emits the -D.
    'value.format'                 = 'json'
);

CREATE TABLE IF NOT EXISTS subscriptions_k (
    id              STRING,
    organization_id STRING,
    customer_id     STRING,
    external_id     STRING,
    plan_id         STRING,
    status          INT,
    started_at      BIGINT,
    terminated_at   BIGINT,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector'                    = 'upsert-kafka',
    'topic'                        = '${cdc.topic.prefix}.public.subscriptions',
    'properties.bootstrap.servers' = '${kafka.bootstrap.servers}',
    'properties.group.id'          = '${kafka.group.id}_dim_sub',
    'key.format'                   = 'json',
    -- NOTE: do NOT set 'value.json.ignore-parse-errors' here. A delete
    -- arrives as a tombstone (null value); with parse errors ignored the
    -- format swallows it and upsert-kafka never emits the -D.
    'value.format'                 = 'json'
);
