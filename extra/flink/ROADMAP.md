# Flink realtime usage — plan and running record

Companion to `extra/risingwave/ROADMAP.md`. Same problem, different engine.

---

## ▶ START HERE (resume point, 2026-09-02)

### Status

| Gate | State |
|---|---|
| 0 — toolchain, connector-on-2.3 | ✅ done |
| 1 — Postgres CDC | ✅ done — **one slot for all 6 tables, `REPLICA IDENTITY DEFAULT`** |
| 2 — stage 0: enrichment + dedup | ✅ done — plan shape confirmed, watermark stall fixed, semantics verified |
| 3 — stage 1: dimensions + JVM UDFs | not started |
| 4 — stage 2: 15-minute usage buckets | not started |
| 5 — A/B against RisingWave | 🟡 **Flink half measured** — stage 0 at 80k+ ev/s on this box; RisingWave not yet re-run locally |

**The POC's central question is still open, but the most important early
signal is in and it is positive**: Flink compiles the dedup to a hash-sharded,
insert-only `Deduplicate` operator with no clock-driven filter anywhere — i.e.
RisingWave's fragment 119 construct does not exist here. Whether that
translates into throughput past ~37k ev/s is Gate 5.

### Do this next, in this order

Gate 2 is closed (stall fixed, semantics verified) and the Flink half of the
throughput question is answered on this box: **stage 0 sustains 79k ev/s and
peaks at 83k, with the `Deduplicate` operator — RisingWave's wall — at 17%
busy** (full record and caveats: Gate 5 → "First pass"). What is left:

1. **Re-run RisingWave's stage 0 on THIS box**, against `events-raw-bench` with
   the same `scripts/bench-load.sh` producer and a cold start. Until that runs,
   there is no A/B: the 36–37k RisingWave number is from Redpanda Cloud plus a
   cloud tier and is not comparable to a laptop number in either direction.
   `lago start risingwave`; the volume `lago_dev_risingwave_data_dev` is intact.
2. **Then decide whether the Flink number is worth raising.** The bottleneck is
   the `TemporalJoin` (94% busy on its hottest subtask), and `billable_metrics`
   is **83 rows** — a broadcast or lookup join would remove the shuffle and the
   skew entirely. Cheap experiment, and it also removes the watermark coupling
   that Gate 2 had to work around.
3. **Then** Gate 3 (JVM UDFs) and Gate 4 (15-minute buckets) for a
   full-pipeline comparison. Neither is needed for the headline question.

**How to run a measurement** (do not skip the middle step — a starved
TaskManager measures RocksDB, not the pipeline):

```sh
FLINK_TM_MEMORY=12288m docker compose -f docker-compose.flink.yml up -d flink-taskmanager
./scripts/submit.sh --kafka.topic.events-raw events-raw-bench --kafka.group.id <fresh>
SUBS_PER_BM=8 ./scripts/bench-load.sh --topic events-raw-bench --rate 140000 --ramp 150 --duration 60 &
./scripts/bench-watch.py --interval 10 --samples 22
```

### Live environment state

- **Flink cluster UP**: `lago_flink_jobmanager` + one taskmanager (8 slots),
  http://localhost:8081 or https://flink.lago.dev.
- **No job running** — the last benchmark job was cancelled after the 2026-09-02
  measurement. Only one stage-0 job may run at a time: they cannot share the
  replication slot `lago_flink_billable_metrics`, so cancel before submitting.
- **Benchmark topic `events-raw-bench`**: 12 partitions, 1 replica, mirroring
  the staging topic the RisingWave scale-day numbers came from, capped at
  `retention.ms=30m` / `retention.bytes=256MB` per partition so a load run
  cannot fill the disk. Point a run at it with
  `--kafka.topic.events-raw events-raw-bench`. Recreate it between runs for
  clean offsets.
- **The TaskManager now runs with 12 GB** (`FLINK_TM_MEMORY`, and the compose
  default was raised to match). At the old 4 GB it starves RocksDB and the
  measured ceiling is a memory artifact — see Gate 5 "First pass".
- **Benchmark tooling**, both engine-agnostic and meant to be shared with the
  RisingWave re-run: `scripts/bench-produce.mjs` (paced producer, 144k ev/s
  proven), `scripts/bench-load.sh` (pulls event shapes from the live catalog,
  reports the distinct join-key count), `scripts/bench-watch.py` (per-vertex
  out-rate, busy avg/max across subtasks, backpressure).
- **Submit-time overrides**: any config key can now be overridden on the
  submit line (`AppConfig.load(args)`), e.g.
  `./scripts/submit.sh --stage0.sink.connector print --pipeline.explain true`.
  MSF passes no application arguments, so this layer is inert on the platform
  and cannot silently diverge production from its PropertyGroup.
- **RisingWave STOPPED, not removed.** `lago start risingwave`; volume
  `lago_dev_risingwave_data_dev` intact, CDC + MVs resume on their own. Its
  slot `risingwave_dev` is inactive and pinning WAL — expected while stopped.
- **Kafka Connect STOPPED** and its Debezium connector deleted — that path was
  retired (see Gate 1 "DECIDED"). Kept as documented fallback only.
- **Dev Postgres changed** (in `postgresql.auto.conf` on the volume, NOT in the
  committed compose file): `max_replication_slots` / `max_wal_senders` 4 → 20.
  **No `REPLICA IDENTITY` change remains** — both tables were reverted to
  DEFAULT and must stay there.
- **Everything is UNCOMMITTED** on branch `poc/risingwave-realtime-usage`:
  `extra/flink/` and `extra/kafka-connect/lago-dimensions-cdc.json` are
  untracked. Offer to commit if durability matters.

### Rebuild and run

```sh
lago up -d                      # dev stack: network + redpanda + db
cd extra/flink
./scripts/setup-postgres-cdc.sh # idempotent; prints slots + retained WAL
./scripts/build.sh              # builds in a container (no local JDK/Maven)
./scripts/up.sh
./scripts/submit.sh
./scripts/logs.sh               # `print` sink output lands here
```

**Read the plan before measuring anything.** Set `pipeline.explain = true` in
`app/src/main/resources/local.properties` (or a file pointed at by
`LAGO_FLINK_CONFIG`) and submit: it prints the planner's execution plan and
exits without creating a job, a consumer group, or a replication slot. The
RisingWave ceiling was a plan-shape problem that took days of elimination to
name; here the same answer is free and static.

---

## Why this exists

The RisingWave PoC works and is fast, but it stopped at a wall nobody could
remove. 2026-09-01: **20K ev/s clean** (wallet p50 826ms), and a saturation
ceiling at **36–37K ev/s** that stayed *invariant across six configurations* —
sink parallelism 8→64, cold restart at tier 0, widened parallelism relics, all
falsified as causes. The ceiling was catalog-localised to **fragment 119**: a
`NOW()`-driven `DynamicFilter` (the replay guard, which *is* the dedup TTL)
joined ahead of the dedup/sink at parallelism 8, capping ~**580 ev/s/actor**.
The static-literal workaround was retracted — it would unbound the dedup state.

That leaves one binary question:

> **Is the wall structural to RisingWave's implementation, or structural to the
> workload?**

Flink answers it, because Flink solves the same two sub-problems with different
machinery. Where RisingWave needed a hand-built bounded working set — a
`now()`-driven temporal filter whose expiry retractions sweep operator state,
landed into append-only firewall tables with `retention_seconds` — Flink has
`table.exec.state.ttl` handled by the state backend. Where RisingWave plans
first-wins dedup as GroupTopN behind that dynamic filter, Flink's planner
recognises `ROW_NUMBER() OVER (PARTITION BY key ORDER BY proctime) = 1` and
compiles it to a dedicated Deduplicate operator keyed by hash, which shards
with parallelism.

**If Flink scales past ~37K on comparable hardware, the wall is RisingWave's.
If Flink plateaus in the same region, the wall is the problem's.** Either
answer is worth the build.

A second motive, independent of the benchmark: **production would run on Amazon
Managed Service for Apache Flink (MSF)**, so everything here is shaped to be
liftable to AWS rather than to be a throwaway.

## Non-goals

This is **not** a migration and not a full port. Out of scope until the
benchmark answers its question:

- wallet triggers and the refresh-consumer path
- Postgres sinks and the observability MVs
- coverage beyond `count` / `sum` aggregations
- the recurring-BM `FetchSubscription` fallback (also still open on RisingWave)
- custom-expression evaluation (`billable_metrics.expression`)

---

## 0. Decisions taken, with the evidence

### Runtime: Apache Flink 2.3.0 on Java 17 (Jeremy's call, 2026-09-01)

MSF added 2.3 support in July 2026, and the AWS build convention is literally
`mvn package -Dflink.version=2.3.0`. Two 2.3 features are directly on the
critical path of what we are measuring:

- **FLIP-558 — `SinkUpsertMaterializer` and changelog disorder.** Explicit
  `ON CONFLICT` handling (`DO NOTHING` / `DO ERROR` / `DO DEDUPLICATE`), which
  the release notes say "addresses prior performance issues from unbounded
  state growth". The 15-minute usage aggregation is a retract stream landing in
  ClickHouse; the materialiser's state is exactly the thing that would blow up
  there.
- **`TO_CHANGELOG` / `FROM_CHANGELOG`.** `TO_CHANGELOG` materialises a dynamic
  table into an append-only stream — a direct analogue of the RisingWave
  design's `force_append_only` retraction firewall, available as a first-class
  SQL operator instead of a sink trick.

Also inherited from 2.x: `VARIANT` for semi-structured data (relevant to the
`properties` decision below), `StreamingMultiJoinOperator`, Delta Join,
ProcessTableFunction, RocksDB 8.10, Kryo 5.6.

**Rejected: Flink 1.20 / Java 11.** It is the 1.x LTS with the widest connector
support, but it is the end of the line, a 2.x migration would be a certainty
with known state incompatibility (Kryo 2.24→5.6), and it has none of the
features above.

### Connectors — pinned, and the AWS docs are stale on one point

| Concern | Artifact | Version | Note |
|---|---|---|---|
| Kafka / Redpanda / MSK | `flink-connector-kafka` | `5.0.0-2.2` | **verified on 2.3.0, Gate 0** |
| Postgres CDC | `flink-sql-connector-postgres-cdc` | `3.6.0-2.2` | resolves + shades; not yet exercised |
| JDBC | `flink-connector-jdbc-core` / `-postgres` | `4.0.0-2.0` | exists — see below |

The AWS "Connector availability for Flink 2.2" table says JDBC is **"Not yet
released for 2.x"**. That is **out of date**: the JDBC connector was split into
per-dialect artifacts, and `flink-connector-jdbc-core:4.0.0-2.0` and
`flink-connector-jdbc-postgres:4.0.0-2.0` are both on Maven Central. Do not
re-derive this from the AWS page.

Everything published for 2.x is built against 2.2 or 2.0, and nothing promises
2.3 compatibility. Flink keeps the FLIP-27 Source and FLIP-143 Sink APIs stable
within a major version, so they are *expected* to work — Gate 0 exists to
replace that expectation with a measurement, and did.

### ClickHouse sink: go through Kafka, not JDBC

Three options were checked:

1. **ClickHouse's official `flink-connector-clickhouse`** — exists, supports
   both 1.20 and 2.x. **Unusable here**: DataStream API only ("Table API is
   planned for a future release"), and explicitly *no exactly-once*.
2. **Generic JDBC** — the connector exists for 2.x but ships **no ClickHouse
   dialect**. Would mean writing one against the 4.x dialect SPI.
3. **Flink → Kafka → ClickHouse** (Kafka table engine or
   `clickhouse-kafka-connect`). ✅ First-class SQL connector on both sides,
   works on 2.3, and on AWS it is just MSK — the shape production wants anyway.

**Decision: option 3.** Note this is *not* what RisingWave does (it writes
ClickHouse directly), so it is a genuine architectural difference to hold in
mind when comparing — though RisingWave applied `sink_decouple` on 2026-08-31,
so both sides buffer. Mitigation for fairness: **every throughput number gets a
blackhole-sink run first**, so compute cost is measured with the sink out of
the equation.

### MSF constraints baked into the scaffold

These shape the code, not just the deployment. Each one is a thing that would
otherwise be discovered painfully at cutover.

- **The deployment unit is a shaded uber-JAR on S3.** MSF has no SQL client, no
  session cluster, no plugin directory. Hence: a `main()` that runs SQL loaded
  from JAR resources (`SqlRunner`), and every connector bundled.
- **JAR ≤ 512 MB** or the application fails to start. Currently **46 MB**;
  `scripts/build.sh` fails the build if it ever crosses.
- **Config comes from PropertyGroups**, read via
  `KinesisAnalyticsRuntime.getApplicationProperties()`. `AppConfig` reads that
  on MSF and a properties file locally, so **nothing hardcodes `redpanda:9092`
  the way the RisingWave SQL hardcodes it** — that hardcoded broker already
  caused a ghost "sink under creation" incident on RisingWave Cloud.
  Promoting to MSK/RDS must be a PropertyGroup change, never a code change.
- **MSF 2.2+ throws when an application sets a Flink config MSF does not
  allow.** So the job sets *only* `table.exec.*` planner settings. State
  backend, checkpointing and parallelism belong to the platform — and locally
  to `FLINK_PROPERTIES` in `docker-compose.flink.yml`, which reproduces that
  split rather than papering over it.
- **Read-only root filesystem except `/tmp`.** Nothing may write elsewhere,
  including transitively from a library.
- **No Studio (Zeppelin) on 2.3.** There is no managed interactive-SQL surface;
  ad-hoc exploration is local-only.
- **Watermark alignment**: MSF pins `pipeline.watermark-alignment.max-drift=0`
  for backward compatibility, opting *out* of Flink 2.3's new fairness
  behaviour. If we ever want it, it must be set explicitly — and that changes
  backlog-drain behaviour, which is a benchmark-relevant knob.
- **Non-credential IMDS calls are blocked**; **`fullRestarts` metric is gone**
  (use `numRestarts`).

---

## Gate 0 — toolchain proven ✅ (2026-09-01)

**Question:** does a connector built against Flink 2.2 actually run on a Flink
2.3 cluster, against the real Redpanda topic?

**Answer: yes.** Built the uber-JAR (46 MB, `BUILD SUCCESS`), brought up
`flink:2.3.0-java17` JobManager + TaskManager on the `lago_dev_default`
network, submitted, produced one event to `events-raw`, and the `print` sink
emitted it:

```
SMOKE:5> +I[gate0-org, api_calls, gate0-8eafa084, gate0-sub,
            1788293703.155, 2026-09-01T20:15:03.216Z]
```

Job ran at parallelism 8, `flink-version: 2.3.0`. This also confirms the JSON
format parses the production payload shape and that the
`TIMESTAMP_LTZ(3) METADATA FROM 'timestamp'` broker-clock column resolves.

Unlike RisingWave's `proctime()` — barrier-aligned, 0–1s early bias, explicitly
unusable for latency math — Flink's Kafka metadata timestamp is the real broker
append time, so latency accounting gets simpler here.

---

## Gate 1 — Postgres CDC ✅ (2026-09-01)

**Sequenced first at Jeremy's call**, and it was the right order: CDC is the
dependency every later gate sits on, it is the piece most unlike RisingWave,
and — unlike the throughput gates — it is not blocked on the benchmark-topic
prerequisite, so it could be settled immediately. It produced three findings
that would each have been expensive to discover at cutover.

**Result: CDC works, at a real and previously-unpriced cost to the OLTP
database.** Snapshot of `billable_metrics` + `subscriptions` emitted exactly
308 rows (83 + 225, matching `count(*)`), then a canary INSERT → UPDATE →
DELETE produced a correct changelog with zero restarts:

```
+I[…, aggregation_type=0, null]
-U[…, 0, null]   +U[…, 1, null]
-D[…, 1, null]
```

### Finding 1 — one replication slot per table, not one per source

RisingWave declares ONE `postgres-cdc` source and hangs all six dimension
tables off it: **one slot, one WAL sender, total**. Flink's SQL postgres-cdc
connector has no shared-source concept — each table is an independent Debezium
instance, and the docs are explicit that each needs its own `slot.name` to
avoid `replication slot "flink" is active for PID`.

Measured, not quoted: two captured tables produced **two active slots**.

**And it is worse than one-per-table.** With
`scan.incremental.snapshot.enabled = true`, the source takes *additional
transient slots* for snapshot splits. With 3 of 4 slots held (RisingWave's 1 +
Flink's 2), the job died with:

```
PSQLException: ERROR: all replication slots are in use
```

So the budget is `(tables × 1) + snapshot headroom`, not `tables`. Six
dimension tables will want roughly 8–10 slots where RisingWave wants 1.

**Production consequences on RDS**, all of which are new costs this
architecture imposes on the primary database:
- `max_replication_slots` / `max_wal_senders` must be raised — a parameter
  group change, which requires a **reboot**.
- **Every slot pins WAL**, and an *inactive* slot pins it forever until
  dropped. A stopped or crash-looping Flink application therefore becomes a
  disk alert on the primary. Six slots is six of those. (Visible right now:
  the stopped RisingWave still holds `risingwave_dev`, inactive, retaining
  WAL.)
- MSF restarts and rescales churn these connections.

> If this cost proves unacceptable, the escape hatch is to move CDC out of
> Flink entirely: Debezium → Kafka topics → Flink's `debezium-json` format.
> That is **one slot for all tables**, it survives MSF restarts without slot
> churn, the dev stack already runs `redpanda-kafka-connect`, and on AWS it is
> MSK Connect. It was NOT chosen for the benchmark because it would change
> what is being compared — RisingWave keeps dimensions in-engine, so Flink
> should too. Revisit for production regardless of the benchmark outcome.

### Finding 2 — `REPLICA IDENTITY FULL` is mandatory, and its absence CRASHES the job

All six Lago dimension tables are `REPLICA IDENTITY DEFAULT` (primary key
only). **RisingWave has consumed CDC from them for weeks in that state.**
Flink CDC does not tolerate it:

```
IllegalStateException: The "before" field of UPDATE/DELETE message is null,
please check the Postgres table has been set REPLICA IDENTITY to FULL level.
```

This is not a warning and not a dropped row — it **fails the job**. Observed
behaviour before the fix: crash-loop to `numRestarts = 7`, and because each
restart re-runs the snapshot, the canary row was re-emitted as a duplicate
`+I` on every cycle. A pipeline that silently multiplies dimension rows on
restart is exactly the shape of the ~0.4% over-billing duplication the
RisingWave ranked stage-1 produced — worth remembering when reading any parity
diff from a job that has restarted.

`ALTER TABLE … REPLICA IDENTITY FULL` makes Postgres write the **entire old
row** into WAL on every UPDATE and DELETE. On `subscriptions` and `charges` —
small in dev, large and churning in production — that is real write
amplification on the OLTP primary, and a schema-level ALTER on production
tables. **Price this before committing to in-Flink CDC.** It is the strongest
argument for the Debezium-via-Kafka escape hatch above, which pays the same
cost once rather than per consumer.

### Finding 3 — `publication.name` is a Debezium passthrough

Not a native connector option; it is rejected as an unsupported key. Use
`'debezium.publication.name'`. Worth setting explicitly: Debezium's default
autocreate mode would otherwise create a `FOR ALL TABLES` publication, which
is heavy on a production database. Here it reuses the existing 6-table
`rw_publication` — a publication is just a set of tables, and the per-consumer
state is the slot, so two engines sharing one do not interfere.

### DECIDED 2026-09-01 — CDC stays in Flink, on ONE slot, via the DataStream source

Jeremy: *"I would prefer to have CDC in Flink, so I do not have to take care of
it"*, then found the escape from the slot cost — `PostgresSourceBuilder`, the
**DataStream** CDC source, takes `tableList(String...)` and a single
`slotName(String)`.

**Verified end to end, and it settles both objections at once.**

The Flink SQL `postgres-cdc` connector wraps this same source but exposes one
table per DDL, hence one slot each (confirmed: the six-table SQL job created
six slots). The DataStream builder captures N tables in ONE source:

```java
PostgresSourceBuilder.PostgresIncrementalSource.<T>builder()
    .tableList("public.billable_metrics", "public.subscriptions",
               "public.charges", "public.charge_filters",
               "public.charge_filter_values", "public.billable_metric_filters")
    .slotName("flink_lago_dimensions")
    .deserializer(new LagoChangeEventDeserializer())
    .build();
```

Proven with `CdcSlotProbe` (`app/src/main/java/com/getlago/flink/CdcSlotProbe.java`,
a probe, not production code):

| | Result |
|---|---|
| Replication slots for 6 tables | **1** (`flink_lago_dimensions`) |
| Tables captured | all 6, row counts matching `count(*)` |
| `REPLICA IDENTITY` | **DEFAULT** — unchanged, no WAL amplification |
| UPDATE with null before-image | **survives** (see below) |
| Restarts | 0 |

API checks done against the jar rather than the docs: `tableList` really is
`(java.lang.String...)`, `slotName` really is a single `(java.lang.String)`,
and `PostgresIncrementalSource extends JdbcIncrementalSource` exposing
`createEnumerator` / `createReader` — i.e. a **FLIP-27 `Source`**, so it is
valid on Flink 2.x (which removed `SourceFunction`) and it is DataStream, which
is MSF's *primary* programming model. No MSF concern.

**Why the before-image stops mattering.** The canary on REPLICA IDENTITY
DEFAULT produced `op=u` with `before=null` and the job kept running. The crash
in Finding 2 came from `PostgresValueValidator`, reached through
`RowDataDebeziumDeserializeSchema` — a **SQL-connector** code path that this
approach does not go through. Owning the deserializer means a null before-image
is a case we handle, not a fatal error. `changelog-mode='upsert'` is no longer
even needed as a workaround; upsert semantics need only key + after.

**This retires the Debezium/Kafka Connect alternative.** It was the only way to
get one slot; it is not any more, and it cost an extra system to operate plus an
unsolved delete-encoding problem. Connector deleted, slot dropped.
`sql/01b_cdc_dimensions_via_kafka.sql` and
`extra/kafka-connect/lago-dimensions-cdc.json` are kept as a documented
fallback only — see "OPEN — delete encoding" below for why it is not free.

#### What this costs, and what is left to build

The probe used the built-in `JsonDebeziumDeserializationSchema`. Production
needs three pieces:

1. **`LagoChangeEventDeserializer`** — one `DebeziumDeserializationSchema` that
   handles six heterogeneous table schemas.
2. **Routing** — a `ProcessFunction` with an `OutputTag` per table, keyed on
   `source.table`, producing one typed stream each.
3. **Registration** — `StreamTableEnvironment.fromChangelogStream(stream,
   Schema.newBuilder()…primaryKey("id").build(), ChangelogMode.upsert())` per
   table, so **the rest of the topology is unchanged**: stage 1's temporal
   joins still see six versioned SQL tables by name.

Honest costs:
- ~300 lines of Java plus tests, replacing six declarative DDL blocks.
- **Column schemas move from SQL into Java**, so they stop being greppable and
  diffable against `extra/risingwave/sql/01_cdc_dimensions.sql`. Mitigate with
  a single table-descriptor registry that both the deserializer and the schema
  builder read, so a column is still declared exactly once.
- `LagoUsageJob` moves from `TableEnvironment` to `StreamExecutionEnvironment` +
  `StreamTableEnvironment`. Small, but it touches the entry point and
  `SqlRunner`.
- **One source means shared fate**: a stall or failure affecting one table's
  reader affects all six, where six sources fail independently. Dimension
  volume is low so this is minor — but it is a real change in blast radius.

### SUPERSEDED — the two-path analysis that led here

### RESOLVED 2026-09-01 (same day) — both costs removed

Jeremy pushed back: *"can't we have only one replication slot for all tables?
this is a major concern in production. Same for REPLICA IDENTITY FULL"*. Both
turned out to be avoidable. Findings 1 and 2 above stand as descriptions of the
NAIVE configuration; neither is a property of running Flink here.

#### `REPLICA IDENTITY FULL` — not required. Use `changelog-mode = 'upsert'`

The connector has a `changelog-mode` option, documented as: *"upsert mode can
be used for tables with primary keys when replica identity FULL is not an
option."*

- `'all'` (default) — retract stream using all RowKinds; needs the full
  before-image from Postgres, hence REPLICA IDENTITY FULL.
- `'upsert'` — key-only deletes and idempotent upserts; Flink reconstructs the
  before-image itself in a **ChangelogNormalize** operator (confirmed present
  in the job graph).

**Verified with both tables reverted to `REPLICA IDENTITY DEFAULT`**: the
canary INSERT → UPDATE → DELETE produced a changelog *identical* to the
REPLICA IDENTITY FULL run — `+I` / `-U`,`+U` with the correct before-image /
`-D` with full values — 0 restarts.

The cost moves from **WAL write amplification on the OLTP primary** to
**state in Flink**, holding one entry per dimension row. That state is bounded
by CATALOG SIZE, not event volume, which is the right side of the trade. The
`ALTER TABLE … REPLICA IDENTITY FULL` statements were reverted; do not
reintroduce them.

#### One slot for all tables — not possible *inside* Flink, but possible

Tested directly: pointing two Flink CDC tables at the same `slot.name` fails
with `PSQLException: ERROR: replication slot "lago_flink_shared" already
exists`. The connector creates the slot per source and they collide. There is
no shared-source concept, so within Flink SQL CDC it is genuinely one slot per
table.

**So move CDC out of Flink.** One Debezium connector on Kafka Connect with a
`table.include.list` covering all six dimension tables — **verified: one slot
(`lago_debezium`), six topics, connector and task RUNNING.** The plugin was
already in the repo at `extra/kafka-connect/debezium-connector-postgres`
(Debezium 3.3.1), and `redpanda-kafka-connect` is already a dev service; on AWS
this is MSK Connect. Connector config saved at
`extra/kafka-connect/lago-dimensions-cdc.json`.

This also decouples CDC from the Flink application's lifecycle, so **MSF
restarts and rescales stop churning replication slots** — worth having on its
own, independent of the slot count.

Flink then reads the topics (`sql/01b_cdc_dimensions_via_kafka.sql`). Insert
and update were verified correct end to end through this path with Postgres on
REPLICA IDENTITY DEFAULT.

#### OPEN — delete encoding on the Kafka path

Deletes do not yet flow correctly through the Kafka path. Diagnosed precisely,
not guessed:

- Debezium's `ExtractNewRecordState` SMT with
  `delete.tombstone.handling.mode=tombstone` emits a null *value* but keeps a
  non-null *schema*.
- Kafka Connect's `JsonConverter` returns a true null **only when value AND
  schema are both null**. With a schema present it serialises the JSON literal
  `null` — measured on the wire as `value_bytes=4`, not a real tombstone
  (`value_bytes=0`).
- Flink's `upsert-kafka` therefore never sees a tombstone and hands 4 bytes to
  the JSON format: `Failed to deserialize JSON 'null'` → crash loop.
- `ignore-parse-errors=true` stops the crash but silently swallows the delete.
  `delete.tombstone.handling.mode=drop` loses it entirely (measured: no record
  at all).

**Current state — safe and lossless, but not yet consumed.** The connector runs
`delete.tombstone.handling.mode=rewrite` with `add.fields=op,ts_ms`: no record
is ever null, and a delete arrives as a full row carrying `__op=d` /
`__deleted=true` (verified). Nothing crashes and nothing is lost; the SQL side
just does not interpret it yet.

Two candidate fixes, in preference order:
1. **Flink 2.3's `FROM_CHANGELOG`** — literally designed for this: *"transforms
   an append-only stream that carries an operation column into a dynamic
   table"*. `__op` is that column. This is one of the reasons 2.3 was chosen.
2. A converter that emits genuine tombstones, letting `upsert-kafka` work
   unmodified.

Note the practical urgency is low: Lago dimension tables are **soft**-deleted
(`deleted_at IS NULL` filters throughout the RisingWave SQL), so a hard DELETE
is exceptional. It must not crash or silently vanish — it currently does
neither.

#### Where this leaves the decision

| | Flink CDC per table | Debezium → Kafka → Flink |
|---|---|---|
| Replication slots | one per table (+ snapshot) | **one, total** |
| `REPLICA IDENTITY FULL` | not needed (`changelog-mode=upsert`) | not needed |
| Slot churn on MSF restart/rescale | yes | **no** |
| Deletes | ✅ working today | open (see above) |
| Moving parts | fewer | Kafka Connect / MSK Connect |

**Both rows of this table are now superseded by the DataStream source above**,
which gets one slot AND keeps CDC inside Flink. Kept only to record why the
Debezium path was explored and why it is no longer needed.

### Minor

Debezium emits a **tombstone** (key with null value) after each delete. Flink
CDC logs `Meet unknown element … just skip` at INFO and drops it. Harmless,
but it is one INFO line per delete — noisy under dimension churn.

### Still unproven

Snapshot cost on production-sized tables, behaviour under sustained dimension
churn, slot recovery across a Flink restart, and the Postgres-outage drill
that RisingWave passed on 2026-08-31.

---

## Gate 2 — stage 0: scope and exit criteria

The RisingWave subtree that hit the wall, and nothing else. Depends on Gate 1.

**Build**

1. Postgres CDC source for `billable_metrics` (`flink-sql-connector-postgres-cdc`),
   as a versioned table for temporal join.
2. `events_raw ⨝ billable_metrics FOR SYSTEM_TIME AS OF` — INNER, matching the
   Go processor (a missing/deleted BM dead-letters the event).
3. First-wins dedup on the production ReplacingMergeTree key
   `(organization_id, code, external_subscription_id, timestamp, transaction_id)`
   as `ROW_NUMBER() OVER (PARTITION BY … ORDER BY proctime) = 1`, with
   `table.exec.state.ttl = 32 days`.
4. Blackhole sink.

**The whole point of this gate:** confirm the planner compiles step 3 to a
Deduplicate operator with TTL-based expiry and **not** to something with a
clock-driven join in front of it. Read the plan with `EXPLAIN` *before*
measuring — the RisingWave ceiling was a plan-shape problem that took days of
elimination to name, and here the plan is available up front for free.

**Exit criteria**
- `EXPLAIN` shows Deduplicate (not GroupTopN-behind-a-filter), state TTL applied.
- Dedup semantics verified: replay the same `transaction_id` inside the window →
  one row; outside → two (the agreed 32-day window contract).
- A throughput number at parallelism 8 with a blackhole sink.

### Prerequisite, discovered 2026-09-01 — the topic has ONE partition

`events-raw` is a **1-partition** topic locally. Kafka source parallelism is
capped by partition count, so *any* throughput number taken on it measures a
single reader regardless of the 8 configured slots. The RisingWave staging
investigation lost time to a closely related trap ("the load test only ever
used 2 of the 3 partitions").

**Before any throughput measurement**: create a dedicated benchmark topic with
a partition count matching what staging/production would have, and point
`kafka.topic.events-raw` at it. Do not benchmark on `events-raw` as it stands.

---

## Gate 2 — stage 0: RESULTS (2026-09-01)

### ✅ THE HEADLINE: the dedup plan shape is confirmed

`EXPLAIN` on the stage-0 statement, read before running anything:

```
Deduplicate(keep=[FirstRow], key=[organization_id, external_subscription_id,
                                  transaction_id, code, event_ts],
            order=[PROCTIME], outputInsertOnly=[true])
+- Exchange(distribution=[hash[organization_id, external_subscription_id,
                               transaction_id, code, event_ts]])
   +- Calc(...)
      +- TemporalJoin(joinType=[InnerJoin], ...)
```

Four things in that plan, each answering something the RisingWave
investigation had to earn the hard way:

1. **`Deduplicate`, not Rank/TopN.** The planner recognised
   `ROW_NUMBER() OVER (…) = 1` and compiled it to the dedicated
   keep-first-row operator. (The physical plan shows an intermediate
   `Rank(strategy=[AppendFastStrategy])` which the optimizer then rewrites.)
2. **`Exchange(distribution=[hash[dedup key]])`** — the dedup is sharded by
   hash of the dedup key, so it scales with parallelism. RisingWave's
   fragment 119 capped at ~580 ev/s/actor; this is the structural reason to
   expect different behaviour.
3. **`outputInsertOnly=[true]`** — no retractions leave the dedup. This is
   what RisingWave needed the whole `force_append_only` firewall-table
   architecture to achieve; here the planner establishes it.
4. **NO clock-driven filter anywhere in the plan.** No `NOW()`, no
   DynamicFilter. The 32-day bound is `table.exec.state.ttl`, handled by the
   state backend and invisible to the dataflow. Fragment 119's construct does
   not exist.

The job runs with all four vertices healthy — `KafkaSource` →
`billable_metrics` + `WatermarkAssigner` → `TemporalJoin` → `Deduplicate` →
sink — **on ONE replication slot** (stage 0 reads only `billable_metrics`;
declaring the other five dimension tables costs nothing because a Flink
`CREATE TABLE` is catalog metadata and a CDC source is instantiated only when
a running query reads it).

### Three planner constraints that have no RisingWave equivalent

Each was hit as a hard error, in this order:

1. **Temporal join must include the versioned table's PRIMARY KEY.**
   *"Temporal table's primary key [id] must be included in the equivalence
   condition of temporal join"* — RisingWave joins on any indexed columns and
   carries an explicit `(organization_id, code)` index for this lookup. Fix:
   key the Flink table on `(organization_id, code)`, which Postgres already
   enforces with a UNIQUE (partial) index. Caveat recorded in the DDL.
2. **Processing-time temporal join is not supported at all.**
   *"Processing-time temporal join is not supported yet"* — there is no
   equivalent of RisingWave's `FOR SYSTEM_TIME AS OF PROCTIME()`. The pipeline
   is therefore forced to event-time, with watermarks on both sides. This is
   not a preference; it is a structural difference, and it causes the blocker
   below.
3. **Both sides need the SAME rowtime type.** Broker time is
   `TIMESTAMP_LTZ(3)`, Postgres `timestamp without time zone` is
   `TIMESTAMP(3)`. Aligning them must be done on the APPEND-ONLY side: a
   watermark over a computed column on a CHANGELOG source crashes the planner
   outright (`IndexOutOfBoundsException` in `WatermarkAssigner.copy`, inside
   `SatisfyDeleteKindTraitVisitor`) — a Flink bug, worked around, not fixed.

### ✅ RESOLVED 2026-09-02 — the event-time temporal join stalled on an idle dimension

**The symptom.** The job ran, the plan was right, and no event was ever
emitted. Measured, not inferred:

```
TemporalJoin input watermark    : 2026-09-01 20:44:30.699
max(billable_metrics.updated_at): 2026-09-01 20:44:30.699   <- frozen here
now()                           : 2026-09-01 21:53:36       <- event clock
```

A join's watermark is the minimum of its inputs. The dimension side's
watermark comes from `updated_at`, which only advances when a catalog row
changes — so between catalog changes it freezes and every event sits buffered
behind a watermark that will never arrive. `TemporalJoin` showed `in=83` (the
dimension snapshot) and `out=0`.

**This is the cost of planner constraint 2 above.** RisingWave's
processing-time temporal join cannot have this failure mode, and a
rarely-changing dimension — exactly what a billing catalog is — is the worst
case for an event-time temporal join.

**The fix is one config key: `table.exec.source.idle-timeout = 10 s`**, set in
`LagoUsageJob.applyPlannerConfig`. It marks the idle CDC input idle, the
combined watermark then excludes it, and the join runs off the Kafka side
alone.

**The earlier reading of the plan was wrong.** `EXPLAIN` prints
`idletimeout=[10000]` only on the `events_raw` source scan, which led to
"the setting does not reach the CDC side's standalone `WatermarkAssigner`".
It does; the digest simply does not show it there. Falsified head-on rather
than argued:

| run | `table.exec.source.idle-timeout` | events in | rows out |
|---|---|---|---|
| A | `10 s` | 7 (one batch) | **4** — every expected row |
| B | `0` (disabled) | 6 (same shape) | **0** — the stall reproduces |

Same JAR, same topic, same dimension snapshot, one key changed. Run B is why
this is recorded as *caused*, not *correlated*.

**Two consequences worth carrying forward.**

1. *The trailing record is buffered until the NEXT event arrives.* A left row
   at time `t` is emitted when the watermark passes `t`, and the watermark is
   `t − 5s` (the declared out-of-orderness) until a later event shows up. In
   run A the flush event's own row stayed buffered — correct event-time
   behaviour, invisible under continuous load, but it will distort any
   *single-event* latency probe. Measure latency on a stream, not on one event.
2. *The join is now driven by the event clock alone.* If the catalog changes
   while the dimension side is marked idle, that version lands "late" relative
   to events already in flight. For a billing catalog (writes are rare, and
   nobody expects a price change to apply retroactively to events already
   ingested) this is the same practical semantics as RisingWave's
   processing-time join. It is a real semantic difference, not a free lunch,
   and it is written down here on purpose.

The DataStream-source route (candidate 2 — `WatermarkStrategy.withIdleness()`)
is **no longer needed for this**, but is still wanted for the one-slot win in
Gate 1. The two motivations are now independent again.

### ✅ Stage-0 semantics verified 2026-09-02

Run with `--stage0.sink.connector print` (the sink is switchable on the submit
line now; `blackhole` stays the default so a throughput run never measures the
console writer). Seven events produced in one batch, plus a later flush event
to advance the watermark:

| input | expected | observed |
|---|---|---|
| 3× identical dedup key (`dup-…`) | 1 row | **1 row** ✅ |
| 1× unique `transaction_id` | 1 row | **1 row** ✅ |
| 1× `code` with no billable metric | dropped by the INNER join | **absent** ✅ |
| 2× same `transaction_id`, different `timestamp` | 2 rows (the key includes `event_ts`) | **2 rows** ✅ |
| the flush event itself | buffered until a later watermark | **buffered** ✅ |

Enrichment columns on every emitted row were correct against the catalog:
`billable_metric_id=44cf7be8-…`, `aggregation_type_code=0` (count),
`field_name=null`, `recurring=false`.

That last row of the table is the RisingWave-parity point that matters: the
dedup key is the production ReplacingMergeTree key *including the event
timestamp*, so a re-send with a different timestamp is a different event on
both engines.

### Still to do on this gate

Nothing. The remaining stage-0 work is the measurement, which is Gate 5 —
`events-raw-bench` (12 partitions) now exists for it, because `events-raw` has
ONE partition and no throughput number from it would mean anything.


---

## Gate 3 — stage 1: dimension resolution + JVM UDFs

The stage the RisingWave redesign rewrote on 2026-08-28, ported again — and the
reason Jeremy asked about JVM UDFs in the first place.

**Port targets.** The Rust/WASM UDFs in `extra/risingwave/udf/src/` are already
line-by-line ports of the Go processor, so the Java versions are a *second*
translation of the same original. Port from the Go and check against the Rust.

| RisingWave (Rust → WASM) | Flink (Java `ScalarFunction`) | Ported from |
|---|---|---|
| `matching_filter(filters JSONB, properties JSONB) → JSONB` | `MatchingFilter` | Go `models.MatchingFilter` (`models/flat_filters.go:180`) + `HasFilters` / `IsMatchingEvent` / `ToDefaultFilter` |
| `pick_subscription(subs JSONB, event_ts DOUBLE) → JSONB` | `PickSubscription` | Go `ApiStore.FetchSubscription` (`models/subscriptions.go:26`) |
| `extract_grouped_by(pricing_group_keys, properties, accepts_target_wallet) → JSONB` | `ExtractGroupedBy` | Go `enrichWithPricingGroupKeys` (`enrichment_service.go:193`) |
| `json_text.rs` | value-to-text helper | pinned by `json_text_semantics_are_pinned` |

**The 29-test Go-parity suite ports to JUnit against the same fixtures.** That
suite is the acceptance criterion for this gate — not "it compiles".

**Carry forward the formatting decision (Jeremy, 2026-08-28):** property values
compare by **plain JSON text**, *not* a port of Go's `fmt.Sprintf("%v")`. A
`%v`-exact port was built and deliberately removed as overengineering. Accepted
consequence: numerics ≥1e6 / <1e-4 may diverge from the Go path.
**Do not re-propose `%v` parity without evidence that real traffic hits those
corners.** The JS UDF never had it either.

**What should get easier.** RisingWave's inline-Rust UDFs carry real tax:
30–60s compile per `CREATE FUNCTION`, strict-on-SQL-NULL so call sites need
`COALESCE`, `jsonb` args cannot be `Option` (the generated glue calls
`.parse()`), imports must live inside `fn` bodies, helpers after the entry fn.
A Java `ScalarFunction` is a JIT'd method call in the operator's own thread
with none of that. This is Flink's clearest advantage and it should show up as
developer velocity, not necessarily as throughput.

**What could get worse — the open question of this gate.** RisingWave passes
`JSONB`, an already-parsed value. Flink has three choices for `properties` and
they are not obviously ranked:

| Option | Cost | Risk |
|---|---|---|
| `STRING` + parse in UDF (current) | Jackson allocation per event per UDF call | measures Jackson, not the join |
| `MAP<STRING,STRING>` | parsed once by the JSON format | non-string JSON values may not coerce |
| `VARIANT` (2.x) | pre-parsed, no repeated string parsing | JSON-format support for VARIANT unverified |

**Measure all three.** Per-event JSON handling is plausibly the dominant cost
in a JVM UDF pipeline, and getting it wrong would make the whole comparison
report the wrong thing. Whatever wins, resolve dimension arrays to POJOs/`ROW`
at join time so the UDF is pure comparison logic.

**Structure to copy from the RisingWave redesign** (it removed the ~3k ceiling
and is the right shape here too): aggregate each charge's filters and each
`external_id`'s subscriptions into **one row per lookup key**, temporal-join
exactly one row, and let a scalar UDF loop over the candidate array in memory —
the way the Go processor loops over its cache. Do **not** re-encode the
selection as `DENSE_RANK` / `ROW_NUMBER`; that is what materialised the fan-out
as per-event ranking state.

> Worth knowing before trusting the old encoding for anything: the ranked
> stage-1 **duplicated ~0.4% of rows under burst** (GroupTopN interim-winner
> churn, retraction eaten by `force_append_only`) — a live over-billing bug.
> The array+UDF shape has no interim winners. Whatever Flink does here must be
> checked for the same class of defect.

**Exit criteria**
- JUnit parity suite green against the Go fixtures.
- Full-replay diff against the RisingWave `events_expanded` for the same input
  window: zero unexplained rows.
- Chosen `properties` representation justified by measurement, not preference.

---

## Gate 4 — stage 2: 15-minute usage buckets

`TUMBLE(events_expanded, event_time, INTERVAL '15 minutes')` grouped as in
`extra/risingwave/sql/05_usage.sql`, `count` and `sum` only. 15 minutes is the
granularity that makes every real UTC offset land on a bucket wall.

Flink specifics to settle here:

- Continuous emission vs `EMIT ON WINDOW CLOSE`. Ongoing usage needs
  incremental visibility, which means a **retract stream** — and therefore the
  `SinkUpsertMaterializer`, which is where FLIP-558's `ON CONFLICT` clause
  earns its place. Pick the conflict strategy deliberately and record why.
- `unique_count` remains excluded: distinct across buckets ≠ sum of per-bucket
  distincts. Same limitation as RisingWave.
- The `SUM` guard is not cosmetic. RisingWave needed a regex because
  `jsonb ->>` renders small numbers in scientific notation (`0.000001` →
  `'1e-6'`), and a plain-decimal regex silently dropped real units (found in
  the 2026-08-31 parity run). Flink's `CAST` will have its own coercion
  behaviour — **test the exponent cases explicitly**, including whether a bad
  cast nulls the row or kills the job. RisingWave evaluates non-strictly and
  skips the row; Flink may not be so forgiving.
- `last_ingested_at` needs the same `COALESCE(ingested_at, event_time)`
  fallback. Without it, a bucket where every event lacks `ingested_at`
  watermarks NULL, the non-nullable ClickHouse column rejects it, and the sink
  takes the whole database into a recovery loop (measured on RisingWave,
  2026-08-24).

---

## Gate 5 — the A/B, and how to keep it honest

The comparison is worthless if the two sides run on different footing. Controls:

1. **Same box, same core budget.** 32 cores available locally. Give Flink the
   TaskManager slots that match the RisingWave tier the 36–37K number came
   from, and report **ev/s per core** alongside absolute ev/s so a parallelism
   difference cannot launder the result.
2. **Re-run the RisingWave side fresh on this machine.** Do not compare against
   the 2026-09-01 staging numbers from memory — different hardware. The volume
   `lago_dev_risingwave_data_dev` is preserved for exactly this.
3. **Same generator, same event mix.** The loadtest can produce **direct to
   Redpanda at 218k/s** (bypassing the API's ~800/s), byte-faithful — so the
   producer is provably not the ceiling. Use it.
4. **Same partition count** on both sides. See the Gate 1 prerequisite.
5. **Blackhole sink first, ClickHouse second.** A ceiling that moves when the
   sink changes is a sink ceiling.
6. **Cold start each run.** The memory-pressure theory for the RisingWave
   ceiling was falsified precisely by a cold-restart rerun.
7. **Report both saturation throughput and end-to-end latency.** RisingWave's
   20K point had wallet p50 826ms; throughput without latency is half a result.

**Method note, carried over and worth re-reading before the first run:**
backpressure shows you *victims, not causes*. The RisingWave investigation
buried four confident hypotheses by measurement before the fifth survived, and
the ceiling was ultimately named from the catalog, not from a metric. Flink's
Web UI backpressure view and flame graph (`rest.flamegraph.enabled: true`, on)
have the same failure mode. Prefer **amputation tests** — remove a stage and
see whether the ceiling moves — which is what actually proved
`events_expanded_load` was the 3k ceiling.

**No silent caps.** If a run bounds coverage, say so in the write-up.

### First pass — stage-0 throughput on this box (2026-09-02)

**This is half an A/B: the Flink half.** The RisingWave side has NOT been
re-run locally yet, so nothing here may be compared with the 36–37k number —
that one came from Redpanda Cloud plus a cloud RisingWave tier (loadtest run
`20260901205453-a396`). What follows is the Flink stage-0 ceiling on the dev
laptop, and the instrument to measure both engines with.

**Setup.** Stage 0 only (enrichment + first-wins dedup), **blackhole sink**, one
TaskManager with 8 slots, `parallelism.default=8`, RocksDB + incremental
exactly-once checkpoints every 60s, topic `events-raw-bench` (12 partitions,
mirroring the staging topic's shape). Load from `scripts/bench-load.sh`
(`bench-produce.mjs`), which reads event shapes from the live dev catalog so
every event joins a real billable metric. The whole Lago dev stack was running
alongside — this is a laptop, not a clean rig.

**The instrument is not the ceiling**: the producer alone sustains
**144k ev/s** to the local broker (2.17M events in 15s, 0 failed), 4x the
number under test.

| run | TaskManager | event shapes | target | result |
|---|---|---|---|---|
| A | 4 GB (1.4 GB managed) | 500 shapes but **37 join keys, 3 codes = 93% of events** | ramp→100k | peak **42k**, then collapse to ~10k |
| B | 4 GB (1.4 GB managed) | 320 shapes over **79 join keys** | ramp→80k | peak **45–49k**, then sag to ~15k |
| C | **12 GB (4.6 GB managed)** | 79 join keys | ramp→80k | **tracked the whole ramp: 79k/s sustained**, no sag |
| D | 12 GB (4.6 GB managed) | 79 join keys | ramp→140k | peak **83k**, settles **60–75k** |

**Three findings, in order of importance.**

1. **RisingWave's wall does not reproduce, and the dedup is not the
   bottleneck.** At the D ceiling the `Deduplicate` vertex sits at **16–18%
   busy** while `TemporalJoin` runs at **66% average / 94% on its hottest
   subtask** and the source is 84% backpressured. The operator that was
   RisingWave's fragment 119 — the dedup and its clock-driven guard — is idle
   by comparison. Local Flink stage 0 runs at 80k+ ev/s with the dedup barely
   working.

2. **The 4 GB collapse was RocksDB memory starvation, not a ceiling.** Runs B
   and C are the same JAR, same load profile, same key spread; only
   `FLINK_TM_MEMORY` changed (4 GB → 12 GB, managed memory 1.4 GB → 4.6 GB
   across 8 slots). B degraded from 49k to 15k as dedup state grew; C held 79k
   flat. **State-size-driven degradation looks exactly like a structural
   ceiling on a graph and is not one** — which is the same trap the RisingWave
   investigation spent days in, arriving at the opposite verdict there
   (invariant across six configurations = structural).

3. **The bottleneck is the temporal join, which exists only because Flink has
   no processing-time temporal join.** RisingWave gets the same lookup from
   `FOR SYSTEM_TIME AS OF PROCTIME()` for free. Two levers, untried:
   * **key spread** — 79 join keys over 8 subtasks is lumpy (hottest subtask
     94% while the average is 66%); a production catalog has far more
     `(organization_id, code)` pairs, so this is a dev-data artifact that
     *understates* the ceiling.
   * **stop joining altogether** — `billable_metrics` is **83 rows**. A
     broadcast/lookup of a table that size removes both the shuffle and the
     skew. Worth measuring before concluding anything about the join.

**Method note that cost a run.** The first shape query took `LIMIT 500` off the
`billable_metrics × subscriptions` cross product and got 466 of 500 shapes on
three codes. Stage 0 hash-shards on `(organization_id, code)`, so run A
measured **two busy subtasks out of eight** — 86% and 67% busy, the other six
at 1%. `bench-load.sh` now takes N subscriptions *per metric* and prints the
distinct join-key count, and `bench-watch.py` prints busy time as **avg/max
across subtasks**, because an average hides exactly this.

**Still missing before this is an A/B**: the RisingWave re-run on this box
(same topic, same producer, same cold start), ev/s-per-core normalisation, and
a latency number to sit beside the throughput one.

---

## Open questions

- **Does the Deduplicate operator actually scale with parallelism** past the
  region where RisingWave's frag 119 capped at ~580 ev/s/actor? This is the
  headline question; everything else is scaffolding for it.
- **JSON representation** — `STRING` / `MAP` / `VARIANT` (Gate 2).
- **Does Flink CDC hold up under dimension churn and outage?** Gate 1 proved
  snapshot + changelog correctness; it did not prove snapshot cost at
  production scale, slot recovery across a Flink restart, or the Postgres
  outage that RisingWave rides through (drilled 2026-08-31).
- **`SinkUpsertMaterializer` state size** under the retract stream from Gate 3.
- **Are 2.2-built connectors safe on 2.3 beyond the smoke test?** Gate 0 proves
  Kafka loads and reads. CDC and sustained load are unproven.
- **Cost model.** MSF bills per KPU (1 vCPU + 4 GB, `ParallelismPerKPU` default
  1). Once there is a throughput number, KPU-hours per million events is
  directly comparable to the RisingWave Cloud cost model already recorded.

## Risks

- ~~Flink CDC's cost to the primary database~~ — **resolved 2026-09-01**: the
  DataStream `PostgresIncrementalSource` takes all six tables on ONE slot with
  Postgres left on REPLICA IDENTITY DEFAULT, so neither cost survives and CDC
  stays inside Flink. See Gate 1 "DECIDED". Residual: Flink CDC 3.6 is still
  new (released 2026-03-30), and one source means shared fate across the six
  dimension streams.
- **Retract-stream → ClickHouse is the genuinely hard part** of the port, and
  the piece with the least prior art in this codebase.
- **No queryable materialized views.** RisingWave is also the *serving* layer —
  the wallet path reads its MVs over pgwire. Flink has no equivalent: every
  read path needs a sink first. This does not affect the benchmark but it is a
  large architectural difference for any real migration, and it is the reason
  this stays a benchmark until the numbers justify more.

---

## Local operations

```sh
lago up -d                     # the dev stack must be up (network + redpanda)
cd extra/flink
./scripts/build.sh             # builds the uber-JAR in a container (no local JDK)
./scripts/up.sh                # Flink 2.3.0 cluster on lago_dev_default
./scripts/submit.sh            # runs the stages listed in local.properties
./scripts/logs.sh              # TaskManager stdout — where `print` lands
./scripts/down.sh
```

- Web UI: http://localhost:8081 — backpressure and flame graph live here; this
  is the analogue of the RisingWave dashboard at :5691.
- Which SQL runs is `pipeline.stages` in
  `app/src/main/resources/local.properties`; the same key exists in
  `conf/msf-property-groups.example.json` for AWS.
- **RisingWave is stopped**, not removed. `lago start risingwave` brings it
  back; the volume `lago_dev_risingwave_data_dev` is intact and CDC + MVs
  resume on their own.

### Dev-environment changes made for Gate 1

These are **not** in the committed compose file — they live in
`postgresql.auto.conf` on the db volume and in table metadata, so a teammate
cloning the repo will not have them and Gate 1 will fail for them until they
run the same thing. `scripts/setup-postgres-cdc.sh` applies them idempotently.

```sql
ALTER SYSTEM SET max_replication_slots = 20;   -- was 4; needs a db restart
ALTER SYSTEM SET max_wal_senders       = 20;   -- was 4
```

**No `REPLICA IDENTITY` change is needed** — the two tables that were set to
FULL have been reverted to DEFAULT, and `changelog-mode='upsert'` is what makes
that work. Do not reintroduce FULL.

Also running: the `lago-dimensions-cdc` Debezium connector on
`redpanda-kafka-connect` (start it with
`lago up -d redpanda-kafka-connect`, register with
`curl -X POST -H 'Content-Type: application/json' --data @extra/kafka-connect/lago-dimensions-cdc.json http://localhost:8083/connectors`).

To undo: `ALTER SYSTEM RESET max_replication_slots`, restart `db`. Drop a slot
whose consumer is gone for good — inactive slots pin WAL forever:
`SELECT pg_drop_replication_slot('lago_flink_billable_metrics');`

Also worth setting in any environment that keeps slots, dev or prod:
`max_slot_wal_keep_size` (currently `-1`, unlimited). It caps how much WAL a
slot may retain and invalidates the slot beyond that, turning a
disk-full outage on the primary into a recoverable re-snapshot.

### Known gotchas (already paid for)

- **Checkpoint volume ownership.** The named volume is created root-owned, the
  Flink image runs as uid 9999, and the JobManager dies at *"Failed to create
  directory for shared state"*. `scripts/up.sh` chowns it on every start —
  idempotent, leave it there.
- **`ServicesResourceTransformer` is mandatory** in the shade config. Without
  it the `META-INF/services/*Factory` entries collide and every SQL connector
  disappears at runtime behind a *"Could not find any factory"* error that says
  nothing about the real cause.
- **Jackson version skew.** `flink-sql-connector-postgres-cdc` bundles Jackson
  2.18.2. The project pin was moved to 2.18.2 to match; a `jackson-databind`
  older than the bundled `jackson-core` is a runtime landmine, not a warning.
- **`--add-exports` warnings on submit** (`Unknown module: jdk.compiler`) are
  cosmetic on Java 17. Ignore.
- **Recreating the JobManager kills every running job.** The local session
  cluster has no HA and no persisted job-graph store, so a
  `docker compose up -d flink-jobmanager` after a config change silently drops
  in-flight jobs — and any CDC slot they held goes inactive and starts pinning
  WAL. Resubmit after touching the cluster config, or check
  `pg_replication_slots.active`. (MSF does not have this failure mode: it is an
  application cluster with managed checkpointing.)
- **Do not bind-mount `app/target` into the Flink containers.** `mvn clean`
  deletes the directory and the mount goes stale: the JobManager reports
  `JAR file does not exist` until the container is recreated, with a rebuilt
  JAR sitting right there on the host. Mount `app/` and reference
  `target/…` inside it — already fixed in `docker-compose.flink.yml`.
- **`publication.name` is not a connector option** — it is
  `debezium.publication.name`. The validation error lists supported keys and
  does not hint at the passthrough prefix.
- **A crash-looping CDC source re-snapshots on every restart**, so downstream
  sees duplicate `+I` rows for the same dimension row. If a parity diff looks
  like duplication, check `numRestarts` before believing the diff.

### Pre-existing, unrelated

At the time of writing, `lago_api_dev` and all API workers are in a restart
loop (`Restarting (18)`). This predates the Flink work and does not affect it,
but it will block any test that needs the API to produce events — the direct-to-
Redpanda producer path is unaffected.

---

## Status

| Gate | State |
|---|---|
| 0 — toolchain, connector-on-2.3 proven | ✅ 2026-09-01 |
| 1 — Postgres CDC | ✅ 2026-09-01 — **one slot for all 6 tables, REPLICA IDENTITY DEFAULT**, via the DataStream `PostgresIncrementalSource`. Proven by probe; production deserializer + routing still to build |
| 2 — stage 0 enrichment + dedup | 🟡 plan shape CONFIRMED (`Deduplicate`, hash-sharded, insert-only, no clock filter). Job runs, but the event-time temporal join stalls on the idle dimension watermark |
| 3 — stage 1 dimensions + JVM UDFs | not started |
| 4 — stage 2 usage buckets | not started |
| 5 — A/B against RisingWave | 🟡 **Flink half measured** — stage 0 at 80k+ ev/s on this box; RisingWave not yet re-run locally |
