-- Dimension tables replicated live from the Lago Postgres through Flink CDC
-- (Debezium embedded in the job): initial snapshot, then logical replication.
--
-- Mirrors extra/risingwave/sql/01_cdc_dimensions.sql. Postgres uuid maps to
-- STRING; timestamp(6) to TIMESTAMP(3); varchar[] to ARRAY<STRING>.
--
-- ============================================================================
-- TWO THINGS THAT LOOK LIKE BLOCKERS AND ARE NOT — DO NOT "FIX" THEM BACK
-- ============================================================================
--
-- 1. `changelog-mode = 'upsert'` IS WHY POSTGRES STAYS ON `REPLICA IDENTITY
--    DEFAULT`. In the default 'all' mode the source demands a full
--    before-image for every UPDATE/DELETE, which means REPLICA IDENTITY FULL
--    and therefore writing the entire old row into WAL on every mutation of
--    an OLTP table. In 'upsert' mode the source emits key-only deletes and
--    idempotent upserts and Flink rebuilds the before-image itself in a
--    ChangelogNormalize operator. Measured: identical changelog
--    (+I / -U,+U / -D), zero cost to the primary. The state this adds is
--    bounded by CATALOG SIZE, not event volume.
--
--    Without it the job does not degrade — it CRASHES, on the first UPDATE,
--    with "The 'before' field of UPDATE/DELETE message is null", and
--    re-snapshots on every restart (duplicate +I rows downstream).
--
-- 2. ONE REPLICATION SLOT PER TABLE is inherent here and is a deliberate,
--    accepted trade (Jeremy, 2026-09-01): keeping CDC inside Flink means one
--    system to operate instead of Flink + Kafka Connect. Slots cannot be
--    shared — two tables pointed at one slot.name fail with
--    `ERROR: replication slot "..." already exists`.
--
--    What that obliges, on RDS as much as here:
--      * max_replication_slots / max_wal_senders >= (tables + snapshot
--        headroom). Six tables want ~10. On RDS this is a parameter group
--        change and needs a REBOOT.
--      * max_slot_wal_keep_size MUST be set. Every slot pins WAL, and an
--        INACTIVE slot pins it forever — a stopped or crash-looping Flink
--        application otherwise becomes a disk-full outage on the primary
--        database. The cap turns that into slot invalidation and a
--        recoverable re-snapshot.
--      * Alert on inactive slots and on retained WAL per slot.
--        scripts/setup-postgres-cdc.sh prints both.
--
-- PRIMARY KEY ... NOT ENFORCED is REQUIRED on every table: it makes these
-- versioned tables, which is what `FOR SYSTEM_TIME AS OF` needs on the
-- right-hand side of the temporal joins in stage 1.
-- ============================================================================

CREATE TABLE IF NOT EXISTS billable_metrics (
    id               STRING,
    organization_id  STRING,
    code             STRING,
    aggregation_type INT,
    recurring        BOOLEAN,
    field_name       STRING,
    expression       STRING,
    created_at       TIMESTAMP(3),
    updated_at       TIMESTAMP(3),
    deleted_at       TIMESTAMP(3),
    -- KEYED ON THE LOOKUP KEY, NOT ON `id`. Flink rejects a temporal join
    -- whose equivalence condition does not include the versioned table's
    -- primary key:
    --   "Temporal table's primary key [id] must be included in the
    --    equivalence condition of temporal join"
    -- RisingWave has no such rule — it temporal-joins on any indexed columns
    -- and carries an explicit (organization_id, code) index for this lookup.
    -- Stage 0 looks up by (organization_id, code), so that must BE the key.
    --
    -- Safe because Postgres enforces it: `index_billable_metrics_on_
    -- organization_id_and_code` is a UNIQUE INDEX on exactly these columns
    -- (partial: WHERE deleted_at IS NULL). Verified 0 duplicate groups both
    -- with and without soft-deleted rows.
    --
    -- CAVEAT, recorded rather than hidden: the uniqueness is PARTIAL, so a
    -- soft-deleted row and a live row MAY share the key. Ordinary flow is
    -- safe — Postgres forces delete-before-recreate, and Debezium preserves
    -- WAL order — but a later UPDATE touching an already-soft-deleted row
    -- would upsert its (organization_id, code) and clobber the live one.
    -- `billable_metrics` is only ever looked up by (org, code), so nothing
    -- else depends on this key. The rigorous fix is an event-time versioned
    -- VIEW (dedup by ROW_NUMBER over the live rows); it costs moving the
    -- whole pipeline from processing-time to event-time temporal joins, which
    -- is a bigger change than Gate 2 should smuggle in. Tracked as an open
    -- item.
    PRIMARY KEY (organization_id, code) NOT ENFORCED,
    -- A versioned table needs a PRIMARY KEY *and* an event-time attribute.
    -- Dimension rows carry historical updated_at values while events are
    -- current, which is exactly what the temporal join wants: "the version of
    -- this metric as of the event's timestamp".
    --
    -- Zero out-of-orderness: Debezium delivers per-table changes in WAL
    -- order, so there is no lateness to tolerate here.
    --
    -- The CAST is not cosmetic. Postgres `timestamp without time zone` maps to
    -- TIMESTAMP(3), but the event side's rowtime is the Kafka broker clock,
    -- TIMESTAMP_LTZ(3), and Flink requires BOTH sides of an event-time
    -- temporal join to have the SAME rowtime type:
    --   "Event-Time Temporal Table Join requires same rowtime type in left
    --    table and versioned table"
    -- Rails stores these columns in UTC, and table.local-time-zone is pinned
    -- to UTC in LagoUsageJob so this cast cannot drift with the host.
    -- Watermark on the PHYSICAL column. A watermark over a COMPUTED column on
    -- a changelog source crashes the planner outright
    -- (IndexOutOfBoundsException in WatermarkAssigner.copy, during
    -- SatisfyDeleteKindTraitVisitor) — a Flink bug, so the rowtime alignment
    -- is done on the append-only side instead (see 00_source_events_raw.sql).
    WATERMARK FOR updated_at AS updated_at
) WITH (
    'connector'         = 'postgres-cdc',
    'hostname'          = '${postgres.hostname}',
    'port'              = '${postgres.port}',
    'username'          = '${postgres.username}',
    'password'          = '${postgres.password}',
    'database-name'     = '${postgres.database}',
    'schema-name'       = '${postgres.schema}',
    'table-name'        = 'billable_metrics',
    'slot.name'         = '${postgres.slot.name}_billable_metrics',
    'decoding.plugin.name' = 'pgoutput',
    -- Not a native option: Debezium properties pass through with a
    -- 'debezium.' prefix. Naming an existing publication also avoids
    -- Debezium's default autocreate mode, which would create a
    -- FOR ALL TABLES publication — heavy on a production database.
    'debezium.publication.name' = '${postgres.publication}',
    -- Parallel, checkpointable, lock-free snapshot reading. Costs transient
    -- extra slots while snapshotting; that is what the headroom above is for.
    'scan.incremental.snapshot.enabled' = 'true',
    -- See note 1 in the header. This is load-bearing.
    'changelog-mode' = 'upsert'
);

CREATE TABLE IF NOT EXISTS subscriptions (
    id              STRING,
    organization_id STRING,
    customer_id     STRING,
    external_id     STRING,
    plan_id         STRING,
    status          INT,
    started_at      TIMESTAMP(3),
    terminated_at   TIMESTAMP(3),
    created_at      TIMESTAMP(3),
    updated_at      TIMESTAMP(3),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector'         = 'postgres-cdc',
    'hostname'          = '${postgres.hostname}',
    'port'              = '${postgres.port}',
    'username'          = '${postgres.username}',
    'password'          = '${postgres.password}',
    'database-name'     = '${postgres.database}',
    'schema-name'       = '${postgres.schema}',
    'table-name'        = 'subscriptions',
    'slot.name'         = '${postgres.slot.name}_subscriptions',
    'decoding.plugin.name' = 'pgoutput',
    -- Not a native option: Debezium properties pass through with a
    -- 'debezium.' prefix. Naming an existing publication also avoids
    -- Debezium's default autocreate mode, which would create a
    -- FOR ALL TABLES publication — heavy on a production database.
    'debezium.publication.name' = '${postgres.publication}',
    -- Parallel, checkpointable, lock-free snapshot reading. Costs transient
    -- extra slots while snapshotting; that is what the headroom above is for.
    'scan.incremental.snapshot.enabled' = 'true',
    -- See note 1 in the header. This is load-bearing.
    'changelog-mode' = 'upsert'
);

CREATE TABLE IF NOT EXISTS charges (
    id                    STRING,
    organization_id       STRING,
    plan_id               STRING,
    billable_metric_id    STRING,
    code                  STRING,
    properties            STRING,
    pay_in_advance        BOOLEAN,
    accepts_target_wallet BOOLEAN,
    created_at            TIMESTAMP(3),
    updated_at            TIMESTAMP(3),
    deleted_at            TIMESTAMP(3),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector'         = 'postgres-cdc',
    'hostname'          = '${postgres.hostname}',
    'port'              = '${postgres.port}',
    'username'          = '${postgres.username}',
    'password'          = '${postgres.password}',
    'database-name'     = '${postgres.database}',
    'schema-name'       = '${postgres.schema}',
    'table-name'        = 'charges',
    'slot.name'         = '${postgres.slot.name}_charges',
    'decoding.plugin.name' = 'pgoutput',
    -- Not a native option: Debezium properties pass through with a
    -- 'debezium.' prefix. Naming an existing publication also avoids
    -- Debezium's default autocreate mode, which would create a
    -- FOR ALL TABLES publication — heavy on a production database.
    'debezium.publication.name' = '${postgres.publication}',
    -- Parallel, checkpointable, lock-free snapshot reading. Costs transient
    -- extra slots while snapshotting; that is what the headroom above is for.
    'scan.incremental.snapshot.enabled' = 'true',
    -- See note 1 in the header. This is load-bearing.
    'changelog-mode' = 'upsert'
);

CREATE TABLE IF NOT EXISTS charge_filters (
    id              STRING,
    organization_id STRING,
    charge_id       STRING,
    properties      STRING,
    created_at      TIMESTAMP(3),
    updated_at      TIMESTAMP(3),
    deleted_at      TIMESTAMP(3),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector'         = 'postgres-cdc',
    'hostname'          = '${postgres.hostname}',
    'port'              = '${postgres.port}',
    'username'          = '${postgres.username}',
    'password'          = '${postgres.password}',
    'database-name'     = '${postgres.database}',
    'schema-name'       = '${postgres.schema}',
    'table-name'        = 'charge_filters',
    'slot.name'         = '${postgres.slot.name}_charge_filters',
    'decoding.plugin.name' = 'pgoutput',
    -- Not a native option: Debezium properties pass through with a
    -- 'debezium.' prefix. Naming an existing publication also avoids
    -- Debezium's default autocreate mode, which would create a
    -- FOR ALL TABLES publication — heavy on a production database.
    'debezium.publication.name' = '${postgres.publication}',
    -- Parallel, checkpointable, lock-free snapshot reading. Costs transient
    -- extra slots while snapshotting; that is what the headroom above is for.
    'scan.incremental.snapshot.enabled' = 'true',
    -- See note 1 in the header. This is load-bearing.
    'changelog-mode' = 'upsert'
);

CREATE TABLE IF NOT EXISTS charge_filter_values (
    id                        STRING,
    organization_id           STRING,
    charge_filter_id          STRING,
    billable_metric_filter_id STRING,
    `values`                  ARRAY<STRING>,
    created_at                TIMESTAMP(3),
    updated_at                TIMESTAMP(3),
    deleted_at                TIMESTAMP(3),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector'         = 'postgres-cdc',
    'hostname'          = '${postgres.hostname}',
    'port'              = '${postgres.port}',
    'username'          = '${postgres.username}',
    'password'          = '${postgres.password}',
    'database-name'     = '${postgres.database}',
    'schema-name'       = '${postgres.schema}',
    'table-name'        = 'charge_filter_values',
    'slot.name'         = '${postgres.slot.name}_charge_filter_values',
    'decoding.plugin.name' = 'pgoutput',
    -- Not a native option: Debezium properties pass through with a
    -- 'debezium.' prefix. Naming an existing publication also avoids
    -- Debezium's default autocreate mode, which would create a
    -- FOR ALL TABLES publication — heavy on a production database.
    'debezium.publication.name' = '${postgres.publication}',
    -- Parallel, checkpointable, lock-free snapshot reading. Costs transient
    -- extra slots while snapshotting; that is what the headroom above is for.
    'scan.incremental.snapshot.enabled' = 'true',
    -- See note 1 in the header. This is load-bearing.
    'changelog-mode' = 'upsert'
);

CREATE TABLE IF NOT EXISTS billable_metric_filters (
    id                 STRING,
    organization_id    STRING,
    billable_metric_id STRING,
    `key`              STRING,
    `values`           ARRAY<STRING>,
    created_at         TIMESTAMP(3),
    updated_at         TIMESTAMP(3),
    deleted_at         TIMESTAMP(3),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector'         = 'postgres-cdc',
    'hostname'          = '${postgres.hostname}',
    'port'              = '${postgres.port}',
    'username'          = '${postgres.username}',
    'password'          = '${postgres.password}',
    'database-name'     = '${postgres.database}',
    'schema-name'       = '${postgres.schema}',
    'table-name'        = 'billable_metric_filters',
    'slot.name'         = '${postgres.slot.name}_billable_metric_filters',
    'decoding.plugin.name' = 'pgoutput',
    -- Not a native option: Debezium properties pass through with a
    -- 'debezium.' prefix. Naming an existing publication also avoids
    -- Debezium's default autocreate mode, which would create a
    -- FOR ALL TABLES publication — heavy on a production database.
    'debezium.publication.name' = '${postgres.publication}',
    -- Parallel, checkpointable, lock-free snapshot reading. Costs transient
    -- extra slots while snapshotting; that is what the headroom above is for.
    'scan.incremental.snapshot.enabled' = 'true',
    -- See note 1 in the header. This is load-bearing.
    'changelog-mode' = 'upsert'
);
