# RisingWave realtime usage — remaining work

State as of 2026-08-28 EVENING (big day: the 08-27/28 staging ceiling ~3k ev/s was PROVEN to be stage-1 `events_expanded_load` by amputation, then the stage was REWRITTEN the same day — ranking operators replaced by Rust-UDF ports of the Go matching logic over pre-aggregated dimension arrays — applied locally AND to staging, and the ceiling is GONE: flat 5,000 ev/s on the small tier, barriers 19-23ms, usage p50 284ms / wallet p50 603ms under load, full record + rebuild gotchas in §0c; earlier context: 08-24 built and reverted compute-on-read wallet balance, see §3; 08-25 ClickHouse serving cost — org key prefix + monthly partitioning, see §0b): BOUNDED 32-day pipeline — enrichment runs as two
bounded sink queries (first-wins dedup on the prod RMT key over a 32-day
window; events immutable, reprocess removed) into append-only firewall
TABLES `events_enriched`/`events_expanded` (retention 33 days, physical
cleanup); usage on 15-minute buckets of the event timestamp → ClickHouse
`usage_buckets_15m` serving table (billing periods, the period-keyed
`usage_realtime` and the Postgres projections were all DELETED — the API
sums buckets over the Rails-computed period window). RisingWave holds a
~32-33 day working set everywhere; ClickHouse keeps forever-history. API
read path (count/sum incl. charge filters and pricing_group_keys),
event-driven wallet refresh with a CH watermark wait (~0.7s e2e),
latency benchmarks, parity checker over the current period. A load-test +
latency service lives in `loadtest/` (§1) and measures every stage end to end
against a real Lago instance; its first staging run surfaced the
`current_usage` charge-cache cutover blocker recorded in §2. Branches: meta
`poc/risingwave-realtime-usage`, api `feat/realtime-usage`.
Details in `README.md`, numbers in `benchmark/RESULTS.md`.

### Bucket rework 2026-08-21 (Jeremy's call: periods out, 15-min buckets in)

Go/no-go was the CH upsert sink's quiet-tail behavior — measured live:
single event with zero follow-up lands in ~335ms, an update to an existing
bucket after 60s of silence in ~288ms (sink_decouple=disable). The trailing
flush class that killed the RW-side wallet refinements does NOT apply to the
ClickHouse upsert sink. Validated e2e: wallet updated ~400ms median warm after produce (bucket in CH ~250ms; floor = barrier_interval_ms),
aggregator provably reads buckets via the production call path.

Consequences / follow-ups:
- [ ] Prod cutover strategy: buckets covering only part of a period serve a
      PARTIAL total without triggering fallback (no missing-row signal).
      Enable at a period rollover, or replay `events-raw` from period start
      (`scan.startup.mode = 'earliest'` variant), or gate per-organization.
      (Same artifact visible in dev: parity check correctly flags post-wipe
      bucket totals vs full events-store history.)
- [x] `lago-rw-serving` Grafana dashboard REBUILT 2026-08-24 against
      ClickHouse `usage_buckets_15m` (all 7 panels had queried the deleted
      `usage_realtime` / `usage_realtime_projections` /
      `subscription_billing_periods`). Grafana had no way to reach ClickHouse
      at all, so this also added the `grafana-clickhouse-datasource` plugin
      (`GF_INSTALL_PLUGINS` in docker-compose.dev.yml) and
      `extra/grafana/provisioning/datasources/clickhouse.yml`. Same pass fixed
      `lago-rw-latency`, whose e2e panels queried the retired
      `pipeline_latency_e2e`. Every panel query in both dashboards was
      replayed through `/api/ds/query` and returns 200 with rows.
- [ ] Boundary sliver (≤15min of events when a subscription starts or
      terminates at a mid-bucket time): accepted for now; if it ever
      matters, query raw events for the two boundary buckets only.
- unique_count cannot recompose across buckets (distinct ≠ sum of per-bucket
  distincts) — needs its own structure when its turn comes (§3).

## 0. FIXED 2026-08-23 — ranking partition keys narrower than event identity

> **HISTORICAL since 2026-08-28: the ranking stages this section fixed no
> longer exist** — the §0c redesign deleted both (stage 1 is now UDF-based,
> ranking-free). The failure analysis stays worth reading: it documents how
> GroupTopN + force_append_only mis-bills, and the §0c local A/B later
> caught the SAME operator class duplicating ~0.4% of rows WITHIN a
> correctly-keyed partition (interim-winner churn) — the partition-key fix
> below narrowed the bug, the redesign removed the operator.

**Billing-correctness bug, found and fixed 2026-08-23.** Both ranking stages
in `sql/04_enrichment.sql` partitioned on `(organization_id, transaction_id)`
(and `+ COALESCE(charge_id,'')` for the filter stage) — NARROWER than event
identity, which is the stage-0 dedup key `(organization_id, code,
external_subscription_id, event_ts, transaction_id)`. Rails'
`index_unique_transaction_id` is `(organization_id, external_subscription_id,
transaction_id)`, so the SAME `transaction_id` on two different
subscriptions is LEGAL input — and two such events then shared a single rank
partition and competed for its one top-1 slot.

Root cause is what `force_append_only` actually does. It is not a
"drop the expiry retractions" filter: per `src/stream/src/executor/sink.rs`
(v3.0.2) it drops `Delete`/`UpdateDelete` **and rewrites `UpdateInsert` into
`Insert`**. So a rank change is laundered into an *extra appended row*, and a
rank loss is laundered into a *silently missing row*.

Both failure modes reproduced on a faithful replica of the stage-1+2 plan
(same operator chain: append-only LHS -> 2 temporal-join fan-outs ->
32d dynamic filter -> `dense_rank` OverWindow -> `ROW_NUMBER` GroupTopN ->
`force_append_only` sink INTO an APPEND ONLY table):

| case | before fix | after fix |
|---|---|---|
| single event, 3-filter fan-out | 1 row, correct filter | 1 row, correct filter |
| same txn + same code, two subscriptions on one plan | **1 row for 2 billable events** (silent loss) | 2 rows, correct per-subscription attribution |
| out-of-order outranking event, then window expiry | **3 rows for 2 events** (one event twice) | 2 rows, stable across the whole expiry window |

- **Silent event loss (under-billing)** needs only the shared
  `transaction_id`, so it is the LIKELIER of the two: the event whose
  subscription lost the `DENSE_RANK` was discarded outright. There is no
  missing-row signal, so the realtime read path serves the short total
  without falling back.
- **Double counting (over-billing)** needs one more coincidence: event A is
  appended as top-1; event B arrives out of order (older `kafka_timestamp`,
  outranking subscription) so A's retraction is dropped but B is appended;
  when B leaves the 32-day window, **A is re-promoted to top-1 and appended a
  second time**. `usage_buckets_15m` is a plain `COUNT(*)`/`SUM()` over the
  table, so A is billed twice and the ClickHouse upsert overwrites the bucket
  with the inflated value. In prod the second append lands ~32 days after the
  first, into the tumble bucket of A's original `event_time` — i.e. it can
  rewrite a bucket in a period that is still open.

**Fix**: both partition keys widened to the full event identity, so one
partition holds exactly one event's fan-out. No cross-event rank
interference, and expiry empties a partition in one go (all its rows share
one `kafka_timestamp`), so nothing is ever re-promoted and re-appended.
Plan re-verified by EXPLAIN: both temporal joins still `append_only: true`,
dynamic filter still `cleaned_by_watermark: true` (state stays bounded),
sink still append-only.

- [~] **Follow-up: make this a monitored invariant, not just a comment.**
      The Grafana half is DONE (2026-08-24): the `lago-rw-serving` dashboard
      has a "Correctness invariants — both MUST be 0" panel running exactly
      the two queries below against RisingWave. Still to do: the same two
      directions inside `RealtimeUsage::ParityCheckService`, so a regression
      trips in code and not only on a dashboard someone has to look at.
      A regression here is silent by construction:
      ```sql
      -- over-count: more than one row per (event identity, charge)
      SELECT count(*) AS dup_groups, coalesce(sum(n - 1), 0) AS extra_rows
      FROM (SELECT organization_id, code, external_subscription_id, event_ts,
                   transaction_id, coalesce(charge_id,'') AS cid, count(*) AS n
            FROM events_expanded GROUP BY 1,2,3,4,5,6 HAVING count(*) > 1) d;

      -- under-count: enriched events that produced ZERO expanded rows
      SELECT count(*) AS dropped_events
      FROM events_enriched e
      WHERE NOT EXISTS (
        SELECT 1 FROM events_expanded x
        WHERE x.organization_id = e.organization_id AND x.code = e.code
          AND x.external_subscription_id = e.external_subscription_id
          AND x.event_ts = e.event_ts AND x.transaction_id = e.transaction_id);
      ```
      Note the dup query MUST key on full event identity — keying on
      `(organization_id, transaction_id, charge_id)` reports legitimate
      multi-subscription events as duplicates.
- [x] Audited every other rank/dedup construct in `sql/` against event
      identity (2026-08-23): the two stages fixed here are the ONLY ranking
      operators in the tree. Stage 0's `DISTINCT ON` already uses the full
      RMT key (correct — keep it that way); `10_enriched_shadow.sql` is a
      bare projection + 32-day filter with no collapse of its own; the
      `force_append_only` Kafka sinks in `06_sinks.sql`, `07_observability.sql`
      and `09_wallet_triggers.sql` carry no ranking. Their stale
      "ranking flip" comments were corrected in the same change.

## 0b. FIXED 2026-08-25 — ClickHouse serving cost: key prefix + partitioning

Jeremy's question — does `usage_buckets_15m` cost a lot of ClickHouse CPU
compared to the old `events_enriched` current-usage queries? — answered by
benchmark rather than argument. Synthetic `bench` database on the dev
ClickHouse: 172.8M bucket rows across 500 orgs with UUID-shaped ids (20k subs
x 3 charges x 2,880 buckets = one full month), plus 30.2M `events_enriched`
rows. Median of 5 runs, CPU from `system.query_log`. Full method, every
table, and the generator/query scripts are in `benchmark/serving_cost/` —
re-runnable end to end.

**The design holds, by a wide margin.** One subscription+charge, 30-day window:

| path | CPU | rows read |
|---|---|---|
| buckets FINAL, org prefix | 20.6 ms | 74k |
| `events_enriched` dedup CTE, sub at 86k events/mo | 85.9 ms | 180k |
| `events_enriched` dedup CTE, sub at 2.6M events/mo | 10,091 ms (1.05 GiB) | 5.2M |

4x cheaper for a quiet subscription, 490x for a busy one — and the bucket cost
is FLAT in event volume (bounded at 2,880 rows per charge per month) while the
`latest_enriched` GROUP BY + `INNER ANY JOIN` is linear in events.
`events_enriched_expanded` (the feature-flagged `ClickhouseEnrichedStore`) is
worse still: it fans out per charge x filter (240M rows vs 738k for
`events_enriched` in dev).

Write side is a non-issue. At `barrier_interval_ms = 250` +
`commit_checkpoint_interval = 1` (4 commits/s), 120s of sustained writes gave
475 inserts, 116 merges, **0.23 CPU-seconds of merge total**, active parts held
at 3. Storage ~14 bytes/row compressed (172.8M rows = 2.33 GiB).

**What the benchmark actually found: three queries omitted `organization_id`**,
which leads `ORDER BY (organization_id, subscription_id, charge_id,
charge_filter_id, grouped_by, bucket)`. Without it the primary key cannot be
used at all:

| query | as written | with org prefix |
|---|---|---|
| `RealtimeRefreshService#wait_for_buckets` | 100.6 ms / 3.65M rows | 1.9 ms / 8.2k rows |
| `ParityCheckService` per-sub totals | 3,792 ms / 10M rows | ~20 ms / 74k rows |

The wallet poll is the dangerous one: it runs every
`BUCKET_WAIT_INTERVAL = 0.1s` for up to 5s PER WALLET REFRESH. At 200
refreshes/s averaging 3 polls each that is ~60 cores of ClickHouse answering
"did the bucket land yet", against ~1 core with the prefix — the difference
between fine and melting the cluster. `organization_id` was already an
initializer argument on the service. Both queries fixed, each with a comment
saying why the column is not redundant with `subscription_id`. `BucketLookup`
and `HourlyBreakdownService` already scanned the org prefix and were fine.

The third query — `ParityCheckService`'s `DISTINCT subscription_id` sweep —
genuinely has no organization to scope by (it samples across every org on
purpose). Left as is, commented; it leans on partition pruning instead.

**`PARTITION BY toYYYYMM(bucket)` added** (Jeremy's call: easier to maintain).
Applied to all three DDL copies — the Rails migration edited IN PLACE
(`feat/realtime-usage` has no upstream branch, so the migration has never
shipped), `db/clickhouse_migrate/cloud/10_usage_buckets_15m.sql`, and
`clickhouse/usage_buckets_15m.sql`. Measured afterwards on 6 months of history
(83M rows), the parity sweep:

| | rows read | CPU |
|---|---|---|
| flat | 8.98M | 3,141 ms |
| partitioned | 3.72M | 1,079 ms |

2.9x at six months and widening: the partitioned cost stays flat as history
accumulates, the flat one grows linearly. Retention also becomes a
`DROP PARTITION` instead of a TTL mutation, which matters because ClickHouse
keeps forever-history here while RisingWave holds only ~32 days.

**Second-order caveat, worth an alert in prod shadow: `FINAL` point-read CPU
scales linearly with the number of ACTIVE PARTS overlapping the key**, not with
table size. Measured with merges stopped: 15 parts 28 ms, 24 parts 57 ms,
33 parts 151 ms, 42 parts 192 ms, 51 parts 236 ms (~4.6 ms per part). Merges
kept up easily under the 4 commits/s write test, so this is a metric to watch
(active part count on `usage_buckets_15m` in `system.parts`), not a known
problem.

Also fixed: `wait_for_buckets` had NO spec coverage — the existing examples
never passed `expected_ingested_at`, so every one of them took the early
return. New `describe "the bucket wait"` block covers the path and pins the
org scoping with an "another org holds a bucket for that subscription id"
case. Falsification-checked: it fails when the org filter is removed.

Dev and test ClickHouse tables were rebuilt via create-copy-EXCHANGE, since a
partition key cannot be ALTERed in. `usage_buckets_clickhouse_sink` survived
the swap untouched (it inserts by table name over HTTP, and EXCHANGE is
atomic) — verified end to end: one event produced to `events-raw` landed in
ClickHouse in 234 ms, in line with the `barrier_interval_ms` floor.

- [ ] Three Grafana panels run `FINAL` over the WHOLE table with no time
      bound, so they scan all of forever-history every refresh: the overview
      counts and the staleness stat in `usage-serving.json`, and
      "most recently updated" (`ORDER BY last_ingested_at DESC LIMIT 20`) in
      `risingwave-latency.json`. Not touched here because bounding them
      changes what the panels report (totals become windowed totals) — decide
      the semantics, then fix. Every other bucket panel already carries
      `$__timeFilter(bucket)` and now prunes to partitions for free.
- [ ] The `bench` database (~8.8 GiB of synthetic data) is still on the dev
      ClickHouse — `DROP DATABASE bench` when it is no longer wanted.

## 0c. 2026-08-28 — staging ceiling ~3,000 ev/s: PROVEN to be `events_expanded_load` (stage-1), then FIXED same day

> **RESOLVED 2026-08-28 evening.** The stage-1 redesign proposed at the end
> of this section was built, validated locally, applied to staging, and
> load-tested: **flat 5,000 ev/s, zero backlog, 19-23ms barriers** on the
> small tier — see "REDESIGN BUILT AND VALIDATED LOCALLY" and "STAGING
> VALIDATED — CEILING CLOSED" below. Everything above those subsections is
> the investigation record: read it for the method and the eliminated
> hypotheses, not for current state.

Four load runs against the staging cloud stack (RisingWave Cloud +
Redpanda Cloud + ClickHouse Cloud) at a 5,000 ev/s target; measured ceiling
**~3,400 ev/s**. Symptom was "huge latency on the RisingWave consumer group".

Read this section for the METHOD as much as the answer: three hypotheses were
tested and falsified before the real one was located, and each falsification
was a measurement, not an argument.

| hypothesis | verdict | how it was killed |
|---|---|---|
| 3 Kafka partitions too few | **WRONG** | doubled to 6 + parallelism 6: per-partition HALVED, total FLAT |
| external sinks backpressuring | **WRONG** | dropped ~5,800 rows/s of CH sinks; gain was transient |
| `barrier_interval_ms` 250 too tight | **WRONG** | set to 1000; throughput flat, wall-clock latency 2x worse |
| `events_enriched` table write | **WRONG** | fragment 102 writes ~0 bytes to the state store |
| `events_expanded` column width | **WRONG** | target table holds 10.4 MB of 254 MB — 4% of the bytes |

None of the six was correct. The ceiling is real and reproducible; the binding
resource is NOT identified. Read the eliminations, not a conclusion.

Two loadtest bugs were also found and fixed along the way.

### (a) The load test only ever used 2 of the 3 partitions

`redpanda.ts` keyed every produced message
`<organization_id>-<external_subscription_id>` to mirror
`Events::KafkaProducerService`. A run has as many distinct keys as it has
TARGETS — the staging run had 2 — so murmur2 pinned 100% of traffic to 2
partitions, deterministically, every run. Partition 1 had 597,830 messages
from other producers, no reader, and no `source_partition_input_count` /
`source_latest_message_id` series at all. The source fragment had 8 actors
(715-722); only 720 and 722 ever emitted rows.

Effective source parallelism was therefore 2, not 3, and no cluster or
partition change could have moved it. FIXED loadtest-side: new config
`kafka.partitionKey` (`subscription` | `none`), **default `none`** — an
unkeyed message makes kafkajs' DefaultPartitioner round-robin per message
(verified in `partitioners/legacy/partitioner.js`), so a produce batch
spreads over every partition. Nothing downstream is partition-affine
(stage-0 dedup shuffles on event identity). Preflight now prints either
`UNKEYED, round-robin over every partition` or, in keyed mode, how many
partitions the run can actually reach.

### (b) First measurements — what the load actually looked like

With all 3 partitions reading, the rerun still capped at ~3,200 ev/s:

| partition | peak ev/s | peak lag | final lag |
|---|---|---|---|
| 0 | 1084 | 20,361 | 1 |
| 1 | 1084 | 19,276 | 1 |
| 2 | 1024 | 21,035 | 1 |

Lag built to ~20k per partition — messages were sitting in Kafka UNREAD, so
the readers were not starved, they were held back. Meanwhile:

```
barrier inflight duration:   10ms -> 2.10s -> 9.36s
barrier sync to storage:     35ms -> 195ms -> 515ms
barriers issued/sec:          4.0 -> 3.1      (confirms barrier_interval_ms = 250)
barrier batch size:           1.0 -> 2.07     (barriers coalescing = backlog)
process CPU:                 0.43 -> 4.63 of 8 cores (58%)
```

`rate(stream_actor_output_buffer_blocking_duration_ns)` sat at 7.5-8.1 for
fragments 33, 51, 60, 61, 63, 94, 97, 103, 104, 105 — i.e. all 8 actors of
each blocked ~1.0 s/s on their OUTPUT buffer. Everything upstream is waiting
on something downstream, while CPU is half idle.

**The arithmetic that breaks it: a barrier is issued every 250 ms, but
syncing one to object storage takes 515 ms.** Checkpoints are issued twice
as fast as storage absorbs them, barriers queue (9.36s inflight / 250ms
interval = ~37 outstanding), RisingWave throttles the source to protect
itself, and ingest pins at ~3,200 ev/s. Adding partitions adds readers that
get backpressured identically.

Compounding it: the cloud cluster is `component=standalone`,
`pod=risingwave-standalone-0`, `process_cpu_core_num=8` — meta, compute,
compactor and frontend in ONE process on ONE node, so compaction competes
with streaming for the same 8 cores. That is why storage sync degrades from
35ms to 515ms exactly when load arrives.

Nothing was broken: lag fully drained to 1 after the run. This is a
sustained-rate ceiling, not a stall.

### (c) Hypotheses tested and falsified

- [x] **`barrier_interval_ms` 250 -> 1000 TESTED and REVERTED 2026-08-28.**
      Hypothesis was that checkpointing was oversubscribed (sync-to-storage
      0.35s against a 0.25s interval). Applied and confirmed live (barrier
      rate 4.0/s -> 0.63-0.83/s). Result: **throughput unchanged** (3,372 ->
      3,422 ev/s) and wall-clock barrier inflight got WORSE, 9.8s -> 20.45s.
      In barrier COUNT it did improve (39 outstanding -> 20), but visibility
      is wall-clock — a row is visible when its barrier commits — so 1000ms
      loses on latency and gains nothing on throughput. Reverted to 250ms.

### Where the backpressure terminates: `events_enriched` (fragment 102)

Found 2026-08-28 by tracing per-edge backpressure instead of guessing.
`stream_actor_output_buffer_blocking_duration_ns` carries BOTH `fragment_id`
and `downstream_fragment_id`, so the graph can be walked edge by edge.
Blocking per edge, normalised by the fragment's actor count:

```
34 -> 96    94%    <- fragment 34 IS the events_raw source
96 -> 95   100%
95 -> 94    99%
94 -> 92   100%
103 -> 102 101%
104 -> 102 101%    <- everything feeding 102 is pinned
102 -> 101  31%    <- jam releases here
101 -> 99    1%
```

**Fragment 102 is the `events_enriched` table** (confirmed by Jeremy against
the streaming graph). Backpressure is total from the source down to 102 and
collapses immediately after it.

The per-edge trace is SOUND and still the best tool here — it is how the
external sinks and the barrier interval were ruled out. But the conclusion
originally drawn from it ("therefore the state-store write into
`events_enriched` is the constraint") was WRONG and is retracted: fragment 102
never registers above 0 in `state_store_per_table_imm_size`. It writes
essentially nothing. Backpressure terminating at a fragment tells you where
the queue drains, not which resource is scarce.

This retro-explains every negative result above:
- dropping the ClickHouse shadow sinks barely helped, because the jam is
  UPSTREAM of every external sink;
- changing `barrier_interval_ms` did nothing, because the bytes written per
  second are the same whatever the checkpoint cadence;
- CPU sat at 3.1/8 cores (39%) because the process is waiting on object-store
  I/O, not computing — which is also why `barrier_sync_storage` degrades from
  0.035s idle to 0.35-0.52s under load.

**DISPROVED: "3 Kafka partitions is the ceiling."** Held for three runs, and
the direct measurement kills it: the source fragment is **94% output-BLOCKED**.
A partition-starved reader is IDLE waiting for bytes; a 94%-blocked reader has
already read the data and cannot hand it off. More partitions add more readers
that block in the same place. (Per-partition rate has also been invariant at
~900-1,160 ev/s across every configuration tried, which is the signature of a
shared downstream constraint, not a per-reader cap.)

### (d) PARTITION HYPOTHESIS KILLED BY EXPERIMENT (2026-08-28, Jeremy's test)

The cleanest result of the day. `events_raw` taken 3 -> 6 partitions AND
`ALTER SOURCE events_raw SET PARALLELISM = 6` (fragment 34 confirmed 4 -> 6
actors, all 6 partitions confirmed reading).

| | 3 partitions | 6 partitions |
|---|---|---|
| source actors | 4 | 6 |
| per-partition | ~1,140 ev/s | **~503 ev/s** |
| **total** | **~3,422 ev/s** | **~3,021 ev/s** |
| source output-blocked | 94% | 87% |
| CPU | 3.1 / 8 | 3.1-3.9 / 8 |
| peak lag | 39,826 | 50,961 |

**Per-partition throughput halved; the total did not move.** If readers were
the cap, 6 x 1,140 = ~6,800 ev/s. Instead the same ~3,000 was redistributed
across twice as many readers, and the source is STILL 87% output-blocked with
6 actors. Throughput conserved under redistribution is the signature of a
shared DOWNSTREAM constraint, not a per-reader cap.

GOTCHA worth keeping: adding partitions WITHOUT `ALTER SOURCE ... SET
PARALLELISM` would have produced a false negative — fragment 34 had only 4
actors, so 6 partitions would still have been read by 4 readers and the test
would have proved nothing. Splits distribute across source actors; actor count
caps usable partitions. `SET PARALLELISM` accepts `ADAPTIVE` (0) or a fixed
number, capped by the job's `max_parallelism` (fixed at creation).

### Write-path measurements (2026-08-28)

```
state_store sync:                 68 MB/s at peak (3,021 ev/s)
                                  => ~22 KB of state-store sync PER EVENT
uploading_memory_usage_ratio:     0.37   (NOT saturated)
mem_table_spill_counts:           ~0.1/s (negligible)
CPU:                              3.1-3.9 of 8 cores (39-49%)
```

~22 KB/event for a raw event of a few hundred bytes — the amplification across
`events_enriched`, the stage-1 join state, `events_expanded` per charge, and
LSM overhead. Interesting, but see (e): it does NOT decompose the way the
column-removal plan assumed, and 0.37 uploader saturation means the write path
is not demonstrably the limiter. See the CONCLUSION below for what this does
and does not establish.

RETRACTED from an earlier draft of this section: "the compactor competes with
streaming for the same 8 cores". That framing was CPU-shaped and the CPU
numbers (39-49%) do not support it. Withdrawn, not merely softened.

### (e) CATALOG EVIDENCE — the column-removal plan KILLED before it was run

State-store memtable bytes, peak across every run (`state_store_per_table_imm_size`,
labelled by `fragment_id`, free from metrics already collected):

```
fragment 101    244.3 MB     <- the write hotspot, ~10x the next fragment
fragment  95     25.5 MB         and ~3x the sum of all others combined
fragment  94     22.8 MB
fragment  92     12.5 MB
fragment  99     10.4 MB
fragment 107      8.3 MB
fragment 109      7.1 MB
fragment  34       5.8 KB     <- the source
fragment 102        —         <- events_enriched: NEVER above 0
```

`rw_catalog.rw_fragments` then named them:

| fragment | flags | state tables | parallelism | what it is |
|---|---|---|---|---|
| 101 | `SINK` | **7** (113-119) | 8 | stage-1 enrichment join (`events_expanded_load`) |
| 99 | `MVIEW`, `UPSTREAM_SINK_UNION` | 1 | **4** | the `events_expanded` TABLE |
| 94 | `SINK` | 2 | 8 | a sink |
| 95 | — | 2 | 8 | join stage |

A "sink" with 7 state tables and 3 upstreams is not a writer — fragment 101 is
the stage-1 temporal joins against the CDC dimensions plus the ranking stages.
Its 244 MB is **join and ranking state**, not output rows.

**This killed the planned next test.** The proposal was to drop `properties`
and `filters` from `events_expanded` to cut state-store bytes. But those
columns live in fragment 99 — **10.4 MB of 254 MB, about 4%**. The 244 MB sits
in join state that must carry `properties` regardless, because
`filter_match_score(ff.filters, e.properties)` and `properties ->> field_name`
are evaluated INSIDE that join. The rebuild would have cost a 32-day replay to
address 4% of the bytes. Not run. Do not revive it.

### CONCLUSION: measured ceiling, unresolved mechanism (SUPERSEDED — the rewrite below removed the ceiling before the mechanism was ever pinned)

**~2,700-3,400 ev/s on this RisingWave Cloud tier for this pipeline shape**,
reproducible across six configurations. Eliminated, each by measurement:

| ruled out | evidence |
|---|---|
| Kafka partitions | 3 -> 6: per-partition HALVED (1,140 -> 503), total FLAT |
| source parallelism | 4 -> 6 actors, no change; still 87% output-blocked |
| external sinks | dropped ~5,800 rows/s of CH writes; gain transient only |
| barrier interval | 250 -> 1000ms: throughput flat, wall-clock latency 2x WORSE |
| `events_enriched` write | fragment 102 writes ~0 state-store bytes |
| column width in `events_expanded` | target table is 4% of state-store bytes |
| CPU | 3.1-3.9 of 8 cores (39-49%) throughout every run |
| S3 reads from operators | state-store gets ~0-13/s; join/ranking cache misses 0 |
| S3 write saturation | ~12 uploads/s; uploader memory ratio 0.37 |
| barrier alignment | 0.24 s/s at fragments 99/101 — present, minor |
| JS UDF cost | `filter_match_score`: 100k calls in 617ms = **162k/s single-threaded** (trivial payload; even 50x slower clears ~25k ev/s on 8 actors) |
| **tier compute (8 -> 24 cores)** | **ceiling unchanged** (1.8-3.5k ev/s), CPU 4.5-5.4/24 (~20%), parallelism VERIFIED at 24 on all key fragments, storage sync UNCHANGED at 0.42-0.49s/barrier, barrier inflight WORSE (27.5s peak — checkpoint weight grows with actor count). Still one `standalone` pod |
| CDC dimension (`subscriptions`) backpressure | symptom, not cause: lago_pg CDC carried ~0 rows/s during the run — the edge shows 100% blocked because BARRIERS cannot be consumed by the wedged join; backpressure propagates up BOTH inputs of a temporal join |

What is NOT established: which resource actually binds. Best remaining
picture (2026-08-28, after the read-path and UDF eliminations): relative
actor busy-time concentrates **~10x in fragments 101 and 95** (stage-1 join +
ranking — ratio only, counter units unverified), and every actor is
single-threaded and barrier-coupled, so the cap is per-row engine work in
stage 1 (ranking + 7 state tables per row, native code — the JS UDFs are
exonerated) interleaved with checkpoint flush stalls (memtable sync 0.35-0.5s
per barrier; the 0.37 uploader ratio is a 60s average that hides those
bursts). That is a coherent story, not a proven one.

The 24-core A/B (run 2026-08-28, end of day) landed on the pre-registered
"structural" fork: 3x cores, parallelism verified at 24, ceiling and storage
sync both unchanged, CPU at 20%. So the limit is NOT tier compute. What the
upgrade did NOT change: single `standalone` pod, same object-store path —
checkpoint/S3 sync serialization is the last story standing. Barrier inflight
getting WORSE at higher parallelism (27.5s peak) is itself evidence: a
checkpoint collects memtables from every actor, so its cost grows with actor
count — 24 may genuinely be worse than 8-12 for this graph.

LOCALIZED BY THE CONSOLE (2026-08-28, late): the RW console's own
edge-backpressure panels walk the chain with names and find the drop —
`events_raw -> events_enriched_load` 96%, `events_enriched_load ->
events_enriched` 96%, `events_enriched -> events_expanded_load` 99-102%,
then **`events_expanded_load -> events_expanded` 4.5%**. The epicenter is
the STAGE-1 ENRICHMENT JOB `events_expanded_load` (= fragments 101/95, the
~10x busy-time concentration): every input pinned, its output free.
Confirmed victims-by-barrier-propagation: the whole `flat_filters` CDC
chain shows 70-104% blocked while carrying ~0 rows/s (dimension inputs of
the wedged temporal join cannot hand over their barriers), same as
`subscriptions`. Also: all five sinks carried IDENTICAL row totals
(1,291,295), so event->charge fan-out in this population is ~1 — stage-1's
per-event cost is the 3 temporal joins + ranking + 7 state tables at
fan-out 1, not fan-out amplification.

PROVEN BY AMPUTATION (2026-08-28, final test of the day): Jeremy DROPPED
`events_expanded_load` and reran at 5k. Result: ingest hit **5,001 ev/s —
the full offered rate — with barrier inflight at 7-9 MILLISECONDS** (from
16-26s moments earlier) and CPU at 2.6/24 cores. Lag drained to 0. Removing
the suspect removed the ceiling: stage-1 is the bottleneck by causal
demonstration, not inference. Corollary: stage-0 (dedup + BM temporal join +
`events_enriched` table write) ran throughout and swallowed 5k/s at 9ms
barriers — causally exonerated. Whatever `events_expanded_load` does per
barrier (7 state tables, join+ranking state sync) is what turned 250ms
checkpoints into 26s ones. Caveats: one 60s sample at 5,001 (barrier
collapse corroborates); 5k was the OFFERED rate, so stage-0 capacity is
>=5k with ceiling unknown; and the amputated config is diagnostic only —
buckets and wallet triggers receive nothing without stage-1.

### PROPOSED REDESIGN (2026-08-28, late — build AFTER the await-tree confirms)

Jeremy questioned why stage-1 carries a DENSE_RANK on subscriptions and a
ROW_NUMBER on filters at all, given the goal is parity with the Go
events-processor. Answer, from reading both sides line by line: the ranks ARE
the Go behavior, re-encoded —
  * sub DENSE_RANK = `FetchSubscription`'s `ORDER BY terminated_at DESC NULLS
    FIRST, started_at DESC LIMIT 1` (models/subscriptions.go:40); the join
    fans out to every subscription row of the external_id, the rank keeps 1
    (`subscription_valid` replaces Go's WHERE because the LEFT join must keep
    no-sub events);
  * filter ROW_NUMBER = the `MatchingFilter` loop (models/flat_filters.go:180
    — match, most-keys wins, default-bucket fallback), re-encoded as
    `filter_match_score` + rank per (event, charge).
Same semantics; wildly different cost model. Go's candidates live for
microseconds in a loop over cached rows. The SQL encoding turns the fan-out
rows into OPERATOR STATE: rank/GroupTopN must be able to re-emit a new winner
if inputs change, so they materialize candidate rows per event-identity
partition (the §0 fix made those partitions correct AND fat) and sync them to
object storage EVERY BARRIER. That is the 7 state tables / 244MB memtables /
(proven tonight) the ~3k ceiling. A per-event LIMIT 1, paid at
streaming-state prices.

THE CHANGE — make RW do it the way Go does (loop over a small array, not a
streaming operator):
  1. FILTERS: aggregate each charge's filters into ONE JSONB array per
     (org, plan, code, charge) — one more level on the existing flat_filters
     aggregation. Temporal-join ONE row per (event, charge); a scalar UDF
     `matching_filter(filters_array, properties)` returns the winner. The UDF
     is a LINE-BY-LINE PORT of Go's `MatchingFilter` (default bucket
     included) — parity becomes a direct port instead of a score+ORDER BY
     re-encoding of it. ROW_NUMBER stage deleted.
  2. SUBSCRIPTIONS: same shape — MV aggregating rows per (org, external_id)
     into an array; one-row temporal join; `pick_subscription(subs_array,
     event_time)` ports Go's ordering. DENSE_RANK stage deleted.
Stage-1 becomes: two single-row temporal joins + two scalar UDFs —
structurally identical to the Go processor (cache lookup + loop). Fan-out 1,
both ranking operators and their state GONE; remaining new state = tiny
dimension-side aggregates updated only on CDC churn. Sink-into-table
firewall architecture UNTOUCHED (stage-0 proved the mechanism at 5k/9ms
tonight) — only the job's interior changes.

Evidence already priced the trade: `filter_match_score` measured 162k
calls/s single-threaded (617ms / 100k, trivial payload) — scalar compute is
the cheap resource; per-barrier ranking-state sync is the expensive one.

GATE: build only after the await-tree names the rank/state-sync path as what
the actors await (today's score: four confident hypotheses died by
measurement — the fifth does not get built on inference). Worth doing for
parity alone, but sequence it. Gotchas when building: it is a stage-1
rebuild = the events_expanded subtree dance (32-day replay, wallet consumer
re-seek, capture-DDL-first on cloud); array MVs must handle a charge/sub
with NO rows (LEFT join semantics preserved); UDF must reproduce Go's
tie-breaks exactly (most-keys, then Go's iteration order vs SQL's
charge_filter_key ordering — VERIFY on a parity window before trusting).

### REDESIGN BUILT AND VALIDATED LOCALLY (2026-08-28, gate waived by Jeremy)

Jeremy called the build without waiting for the await-tree ("we agreed the
ranking for sub and filters is the bottleneck"). Applied on the LOCAL dev
stack the same day; staging validation still pending.

WHAT SHIPPED (all on the poc branch, uncommitted at time of writing):
  * `extra/risingwave/udf/` — a Cargo crate holding the UDF sources with a
    29-test parity suite mirroring the Go tests (`cargo test`), plus
    `gen_sql.sh` which assembles `sql/03_functions.sql` VERBATIM from the
    same files. 03 is now a generated file — edit the .rs, not the SQL.
  * ALL UDFs are now embedded RUST (LANGUAGE rust, compiled server-side to
    WASM — works out of the box on the v3.0.2 docker image; each CREATE
    FUNCTION takes ~30-60s to compile). JS UDFs deleted. Inline-Rust
    gotchas: body must START with the `fn` named like the SQL function
    (imports go INSIDE fn bodies, helper fns AFTER the entry fn); jsonb args
    cannot be Option (the generated glue calls .parse() on them) but
    Option RETURNS work; WASM UDFs are STRICT on SQL NULL (call sites
    COALESCE where Go accepts nil).
  * `matching_filter(filters_agg, properties) -> jsonb` and
    `pick_subscription(subs, event_ts) -> jsonb` — ports of Go
    `MatchingFilter` / `FetchSubscription` selection logic (match,
    most-keys-wins, default bucket, sub ordering incl. ms-truncation);
    `extract_grouped_by` re-ported to Rust.
  * FORMATTING DECISION (Jeremy, 2026-08-28): property values compare by
    their plain JSON TEXT (`udf/src/json_text.rs`), NOT a port of Go's
    `fmt.Sprintf("%v")`. Context: a %v-exact port was built first (Go's
    float formatting verified empirically against the events-processor
    toolchain — scientific at decimal exponent < -4 or >= 6, 2-digit
    exponent, so Go renders 1000000 as "1e+06" and 1e-7 as "1e-07") and
    then REMOVED on Jeremy's call: every dialect (Go %v, JS String(),
    serde_json) already disagreed on those corners, the old JS UDF never
    had Go formatting either, and a comparison should just be a comparison.
    Consequence, accepted: numeric properties >= 1e6 or < 1e-4 (and
    compound values) can match filters / render into grouped_by differently
    than the Go path — visible only in shadow-parity comparisons on such
    values. The chosen semantics are PINNED by unit tests
    (`json_text_semantics_are_pinned`) so they stay a decision, not a
    library accident. Do not re-propose %v parity without new evidence that
    real traffic hits these corners.
  * `02_flat_filters.sql` — new `flat_filters_agg` (one row per (org, plan,
    code, charge), candidates as a jsonb array ordered by charge_filter_key)
    and `subscriptions_agg` (one row per (org, external_id), timestamps
    pre-floored to ms mirroring Go's date_trunc). The old `flat_filters`
    TABLE + sink + index are GONE (flat_filters_mv stays, the agg builds on
    it). Timestamps inside jsonb are stringified ::varchar (RW renders
    jsonb timestamps ISO-T; ::varchar keeps the space form ::timestamp
    parses back).
  * `04_enrichment.sql` stage 1 — both rank stages deleted; two single-row
    temporal joins + the two UDFs. The stage-1 32-day temporal filter is
    ALSO gone: its only purpose was sweeping ranking state, and stage-1
    per-event operator state is now ZERO (append-only-LHS temporal joins
    keep no LHS state). Entry stays bounded by stage-0's filter; a stage-1
    rebuild now replays the full ~33d retention window instead of 32d.
  * `reapply_enrichment.sh` teardown extended: UDFs + agg relations +
    legacy flat_filters (a changed 02/03 needs them dropped to reapply).

LOCAL A/B, 100k-event burst blast (same box, same fixtures: 90% load-plan
traffic across 203 subs x 3 codes, 10% heavy 20-filter-candidate charges;
single-partition local topic; produce itself ~1s via rpk):

| metric (burst of 100k) | ranked stage 1 | UDF stage 1 |
|---|---|---|
| drain after produce end | ~21.3s (~4.7k ev/s) | **<= 2.6s (>= 38k ev/s, poll-bound)** |
| visibility avg / p95 / max | 1.69s / 16.9s / 17.4s | **26ms / 387ms / 420ms** |
| stage-1 state @ 272k events | **3.2 GB**, 7 state tables (4 x 808k keys) | **~10 KB** (backfill tracker only) |
| duplicate rows emitted | +373 and +383 per 100k run | **0** |

PARITY: full-table diff old vs new events_expanded over the replayed 272,460
events: ZERO unexplained divergences. The 1,296 old-only rows decompose as
896 DUPLICATES the ranked pipeline had emitted (see below) + 400 keys whose
old rows predate the 2026-08-25 Hooli region filters (rebuild replays
against current dimensions — known temporal-join backfill semantics, the
new rows are the correct-today attribution). Functional spot checks: gold
matches, bronze/GOLD -> default bucket (case-sensitive like Go), 20-candidate
no-match -> default bucket, grouped_by exact, buckets flow to CH, wallet
consumer drains.

FOUND ALONG THE WAY — the ranked stage 1 DUPLICATES rows under burst: both
100k baseline runs appended ~0.4% extra rows (373, then 383; 896 total in
history), overwhelmingly on the 20-candidate default-bucket class, some
byte-identical within one barrier. Mechanism: GroupTopN interim-winner churn
inside an epoch — interim top-1 emitted, retraction swallowed by
force_append_only, final winner appended again; the differing interim
charge_filter_key is masked by the default-bucket CASE so rows can collide
into identical output. This was ALWAYS live under load (usage_buckets sums
it = over-billing); the §0 2026-08-23 partition-key fix removed CROSS-event
interference but not WITHIN-partition churn. The UDF stage 1 eliminates the
operator class entirely — exactly-once per (event, charge) held across
272k-row replay + 100k burst.

STAGING/CLOUD ROLLOUT NOTES: cloud rebuild remains manual (capture DDL
first, drop leaves->root, sinks recreated in a sink_decouple session —
§ above); TRUNCATE the CH expanded shadow before the rebuild (plain
MergeTree, replay duplicates) and seek the wallet consumer group to end
after backfill (this rebuild replayed ~272k triggers locally). RW Cloud
question RESOLVED same evening: embedded LANGUAGE rust compilation works
on the managed tier out of the box (the BASE64/wasm32-wasip1 fallback was
not needed).

### STAGING VALIDATED — CEILING CLOSED (2026-08-28 evening)

Jeremy applied the rebuild to the staging RW Cloud cluster the same
evening and reran the load. The ~3k ceiling is GONE; the investigation
this section documents is closed.

Rebuild facts worth keeping:
  * The events_enriched->events_expanded BACKFILL digested at 6.7k ->
    **15.6k rows/s** through the new stage 1 (~4M rows in ~6 min), barrier
    inflight 1.5-1.9s DURING backfill, CPU-bound — on the SMALL tier
    (standalone pod reporting 8 cores), i.e. ~5x Wednesday's ceiling
    while doing strictly more per-row work than steady-state ingest.
  * INCIDENT — sink stuck "under creation": the first
    wallet_refresh_triggers_sink CREATE left a catalog entry in creating
    state with NO job behind it (`rw_ddl_progress` empty, DROP SINK
    refused with "exists but under creation"). Likely cause: the create
    hung on an unreachable broker (the local file hardcodes
    redpanda:9092 — see the cloud-parameterisation item below, which bit
    AGAIN) and/or the psql session died mid-backfill. CLEARED by cluster
    restart (`rwc cluster stop/start`; `RECOVER;` is the lighter first
    attempt — forces the same meta recovery that aborts creating-state
    jobs). Prevention: `SET BACKGROUND_DDL = true` before long sink
    creates, and verify the bootstrap address before retrying.
  * `snapshot = 'false'` is NOT available for `CREATE SINK AS SELECT`
    (v3.0.2: FROM-relation sinks only — tested, bind error), and hoisting
    the wallet-trigger projection into an MV to sink FROM is FORBIDDEN
    (a downstream MV over the retention-cleaned events_expanded grows
    unbounded — physical cleanup emits no changelog, canary-proven). So
    wallet-sink recreation keeps the seek-the-consumer-group dance;
    documented in 09_wallet_triggers.sql.
  * METRICS GOTCHA: Kafka sinks never emit `sink_commit_duration_*`
    (only coordinated sinks like ClickHouse do). Do NOT infer a sink's
    absence from it — the reliable liveness signal is a
    `stream_sink_input_row_count` series existing for the sink_id.

THE HEADLINE RUN (id 20260828180122-0375, 18:01 UTC, staging cloud stack,
wallet sink live as sink_id 213, buckets CH sink attached, shadows off):
**712,330 events at a FLAT 5,000 ev/s for 143s — zero errors, zero probe
timeouts, zero Kafka backlog.** Loadtest-measured freshness under that
load (200k samples each, watermark attribution, factor 1.000):
  * event -> usage visible:        p50 284ms / p95 382ms / p99 536ms
  * event -> wallet balance:       p50 603ms / p95 857ms / p99 949ms
    (BETTER than the local 664ms median — full trigger->consumer->refresh
    chain included)
RW during the run: barrier inflight **19-23ms** (Wednesday at 3.4k:
9,000-26,000ms), wallet triggers emitted at 5,000/s, CPU peak 3.6 of the
8 reported cores. Consumed == offered at every sample. The Wednesday
signature (capped throughput + idle CPU + wedged checkpoints) did not
reappear; the graph now behaves compute-bound, which scales with tier.
Results artifact (shareable, product-friendly):
https://claude.ai/code/artifact/dc748e85-9782-4d9a-b09b-5baf37c856ea

NEXT (2026-08-29), REVISED — the RisingWave-team asks are now optional
curiosity, not blockers (the await-tree question died with the ceiling).
Still worth asking if a conversation happens anyway: standalone-tier
object-store bandwidth (sync sat at ~0.45s/barrier across 8 and 24 cores
on the OLD graph) and recommended parallelism for barrier-coupled graphs.
Remaining validation before prod-shadow confidence: a LONG run (10min+)
at 5k+ with the CH shadow sinks recreated (today's run had no shadows;
sinks were a measured contributor on Wednesday), and a ceiling-hunt ramp
above 5k to find the new knee on this tier.

### Still open, cheap, unrelated to the above

- [ ] `events_expanded` (fragment 99) runs at **parallelism 4** while the
      fragments around it run at 8. Graph-wide: 33 fragments at 8, 20 at 4,
      15 at 1. `parallelism_policy` is `upstream_fragment([100])`, and
      `max_parallelism` is 256 with the effective bound at 8 (the core count).
      Free to fix, unrelated to the ceiling.
- [ ] **No cloud-parameterised setup path exists** — `setup.sh` applies
      `sql/*.sql` VERBATIM and every endpoint is hardcoded to local Docker
      (`redpanda:9092`, `http://clickhouse:8123`), and both scripts hardcode
      `-U root` while cloud uses `oauth_default` over `sslmode=require`.
      BIT AGAIN 2026-08-28 evening: the staging wallet-sink create wedged
      in "under creation", most plausibly from the hardcoded broker —
      cost a cluster restart to clear.
      So `reapply_enrichment.sh` MUST NOT be run against a cloud cluster: it
      would drop the subtree and then recreate every sink pointed at
      unresolvable hostnames. Cloud rebuilds are manual today. This is a
      CUTOVER BLOCKER, not an inconvenience — see §2 deployment ordering.

### Method note (worth reusing)

Per-edge blocking normalised by actor count is what finally located this;
aggregate "everything is blocked" told us nothing for three runs. The
signature to look for is the edge where blocking DROPS from ~100% to
something low — that fragment is the bottleneck, everything above it is a
victim. Actor counts differ per fragment (4 vs 8 here), so normalise or the
numbers mislead.
- [x] **Sinks TESTED and largely EXONERATED 2026-08-28.** Two experiments,
      both measured, neither lifted the ceiling:
      1. `sink_decouple = true` on `usage_buckets_clickhouse_sink` (recreated,
         sink_id 141 -> 147). NO effect on throughput or barriers — that sink
         carries only ~15-31 rows/s, ~0.5% of sink volume, because it is a
         15-minute bucket aggregation. Latency-critical is not the same as
         volume-critical; backpressure follows volume. Kept anyway (free).
      2. `events_enriched_rw_shadow_sink` +
         `events_enriched_expanded_rw_shadow_sink` DROPPED — removing ~5,800
         rows/s of ClickHouse HTTPS writes. First minute improved (2,840 ->
         3,372 ev/s, barrier 9.27s -> 6.96s, sync storage 0.52s -> 0.35s) but
         it did NOT hold: by minute two the run was back to 2,739 ev/s,
         barrier 9.8s, and lag climbing to 34,253. The sinks were a
         contributor, not the constraint.
      Sink row amplification for the record: 2,840 events/s in produced
      ~14,500 sink-rows/s out across 5 sinks — every event written 5 times.
- [ ] **Get off standalone.** 8 shared cores is why sync degrades under load;
      the structural fix for real headroom.
- [ ] **Then** raise `events_raw` partitions. Only meaningful once the graph
      is no longer the constraint — today 3 readers are not the limit.

### sink_decouple: what it costs here, and why it is safe

`sink_decouple` is a SESSION variable (`default` | `true`/`enable` |
`false`/`disable`), captured at CREATE SINK time — it does NOT retroactively
change existing sinks, so enabling it means DROP + CREATE. Verify with
`SELECT sink_id, is_decouple FROM rw_sink_decouple;`.

The usual objection is that a decoupled sink commits every 10 checkpoints
(10 x barrier_interval_ms) instead of every one. **That does not apply to
our ClickHouse sinks: all three already pin `commit_checkpoint_interval = 1`**
(`06_sinks.sql:77,120`, `10_enriched_shadow.sql:95`), so flush cadence stays
at the barrier interval and the decoupling buffer only absorbs bursts. This
is why decoupling can be turned on while KEEPING barrier_interval_ms at 250.

Scope deliberately limited to the ClickHouse sinks — they are the slow
HTTPS writers doing the backpressuring. The Redpanda sinks
(`wallet_refresh_triggers_sink`, `usage_realtime_updates_sink`) stay
non-decoupled: they are fast, they are not the backpressure source, and the
wallet trigger's whole value is emitting within milliseconds.

RECREATION HAZARD, per sink:
- `usage_buckets_clickhouse_sink` — SAFE. Recreating replays the whole
  `usage_buckets_15m` snapshot, but it is an `upsert` sink into a
  ReplacingMergeTree keyed on the same primary key, so replay is idempotent
  (expensive, not corrupting).
- `events_enriched_rw_shadow_sink` / `events_enriched_expanded_rw_shadow_sink`
  — DESTRUCTIVE. `append-only` into plain MergeTree with no dedup: a replay
  DUPLICATES all shadow history. Truncate the target first, or accept that
  parity numbers over the replayed window are junk.

## 1. Harden for prod shadow (do first, one chunk)

- [x] **NULL `ingested_at` wedged the whole streaming database** (found and
      fixed 2026-08-24, while moving the expanded shadow to ClickHouse).
      `ingested_at` comes from the event payload; the Lago API always sets it
      (`Events::KafkaProducerService`) but the TOPIC CONTRACT does not, so a
      direct producer, load generator or replayed message can omit it.
      Consequences measured on a single such event produced to `events-raw`:
      `usage_buckets_15m`'s `MAX(ingested_at)` watermarked NULL, ClickHouse
      `last_ingested_at` is non-nullable, `usage_buckets_clickhouse_sink` died,
      and because `DatabaseFailureIsolation` is license-gated (the dev license
      caps at 4 cores, this box has 32) the failure escalated to a FULL
      DATABASE recovery loop: the offending epoch never committed, so the
      source re-read the same event forever and NOTHING advanced — not the
      shadows, not the buckets, not the wallet triggers. One malformed event is
      a total serving outage, with no bad-row quarantine.
      Fixed in two places: `sql/05_usage.sql` watermarks
      `MAX(COALESCE(ingested_at, event_time))` (event_time is <= real ingestion
      time, so the wallet refresh's `last_ingested_at >= watermark` wait errs
      toward waiting, never toward reading early), and the expanded shadow's
      ClickHouse `ingested_at` is Nullable (pure instrumentation — an absent
      value must stay absent, not become a fake timestamp). Both shadow sinks
      also `COALESCE(properties::VARCHAR, '{}')`, the same failure one column
      over.
      - [ ] The general problem is unfixed: ANY non-nullable ClickHouse column
            reachable by a NULL kills a sink, and on a license without
            `DatabaseFailureIsolation` that stops the entire pipeline. Before
            prod, either audit every sunk column against what the topic
            actually guarantees (not what the API happens to send), or put a
            validation/quarantine stage between `events_raw` and stage 0.
            A shadow sink in particular must never be able to stop serving.

- [ ] **State growth: accepted + monitored** (downgraded from "blocking",
      2026-08-21, Jeremy's call). Dedup/event-MV state grows linearly with
      all-time events, but it lives on object store (S3) behind an LSM:
      the per-event dedup lookup is answered by in-memory bloom filters
      for new keys and block cache for recent ones — cold state is never
      on the hot path, so growth degrades cost, not correctness, and only
      slowly latency. Re-measured on v3.2.0-alpha.20260821 (throwaway
      single-node): `StreamAppendOnlyDedup` STILL does not clean state by
      watermark (5 expired keys resident in both key shapes) — no upgrade
      rescue; the rolling-window mechanisms below remain rejected. What to
      monitor in prod shadow before the flip:
      - state size growth/day per internal table (`rw_table_stats`)
      - compactor CPU + S3 GET/PUT rate (write amplification grows ~log
        with state; dedup keys are hash-distributed so old levels keep
        participating in compaction forever)
      - enrich p99 (bloom false positives force occasional S3 reads on
        the hot path; SST metadata cache pressure grows with SST count)
      Act only if these move. Note the bucket MV's agg state is small
      (keys × buckets) and the temporal-filter option stays off the table
      (expiry DELETEs would corrupt CH history through the upsert sink).
      UPDATE 2026-08-21 (later): a bounded design IS now available — see
      "Bounded stage 0" below; implementing it supersedes this
      accept-and-monitor stance for the dedup/enrichment state.

### Bounded stage 0 — Jeremy's design, measured VIABLE 2026-08-21

Pipeline: `events_raw` → [BM temporal join (append-only) → 32-day dynamic
filter on `kafka_timestamp` (`cleaned_by_watermark: true` — state bounded)
→ `GroupTopN` dedup on the prod RMT key] → `force_append_only` SINK INTO an
**APPEND ONLY TABLE** `events_enriched` holding full history. Downstream
(joined/expanded/buckets, CH shadow) reads the table; temporal joins off an
append-only table plan `append_only: true` (verified by EXPLAIN).

Measured on the live dev instance (probe sink + table, since removed):
- isolated event → visible in table: **131ms**; after 60s of total
  silence: **321ms** — the 18–90s trailing-flush rejection of 2026-08-20
  was WRONG for internal-table sinks (it is real for Kafka sinks).
- dedup correctness through the path: 2 byte-identical deliveries + 1
  re-ingest with new value/ingested_at → **1 row** in the table.
- expiry retractions from the bounded MV are dropped by force_append_only:
  the table keeps full history while the MV/dedup state stays ≤32 days.

Semantics: a re-send of a transaction_id >32 days after first ingestion
passes dedup and lands as a duplicate row in the history table and CH —
the agreed 32-day window contract. If the same pattern is later applied to
joined/expanded (bounded MV → append-only table hop before the buckets),
every event-level store in RW becomes bounded except pure history tables
(which accept `retention_seconds` if we ever want to trim them, since
history lives in ClickHouse anyway).

- [x] IMPLEMENTED + APPLIED LIVE (2026-08-21, same day): `04_enrichment.sql`
      is now two bounded sink queries into append-only firewall TABLES
      `events_enriched` and `events_expanded` (retention_seconds 33 days,
      names preserved so every downstream file was untouched;
      `events_joined` folded into the expanded sink). Plans verified: both
      dynamic filters `cleaned_by_watermark: true`, ALL temporal joins
      `append_only: true` (the optimizer keeps the filter above the joins),
      dedup + ranking state swept by the retraction wave, sinks drop it.
      Canary-verified: table `retention_seconds` cleanup is PHYSICAL — a
      counting MV over a 60s-retention table stayed at n=1000 while the
      table itself went to 0 rows. Validated e2e: 3 sends → 1 row in both
      tables, CH shadow 1 row, buckets exact, wallet 664ms.
      GOTCHA (prod-relevant, cuts both ways): recreating jobs over the
      SHARED Kafka source replays retained topic history — the new chain
      backfilled today's events (bucket totals stayed exact through the
      rebuild, wallet math matched to the cent), but the plain-MergeTree CH
      shadow received the replayed uniques a second time (truncated in
      dev). At prod cutover this replay IS the partial-period fix — plan
      the CH-side dedup/truncation accordingly.
- [ ] **Orphaned-event re-injection**: sink NULL-enriched rows (no BM /
      no subscription at enrichment time), re-inject into `events-raw` after
      a delay, alert on second orphaning. Replaces the Go processor's
      12h-retry semantics for CDC races.
- [ ] **Recurring-BM fallback** (no active sub at event time → currently
      active sub) — last enrichment difference vs the Go processor. Since
      the 2026-08-28 redesign the natural home changed: `pick_subscription`
      is a pure UDF (no clock), so the fallback needs a second UDF call at
      a now()-ish timestamp resolved OUTSIDE the UDF — note `now()` is
      rejected in streaming projections, so this likely means carrying
      `rw_received_at`/`kafka_timestamp` as the "current time" argument
      gated on `recurring`.
- [x] **Load-test + latency app for the POC** (2026-08-24): `loadtest/` — a
      local service (Fastify + React, `npm run dev`) that sends events to the
      Lago API for existing customers/active subscriptions and reports
      P50/P95/P99 for every stage, live: RisingWave `events_enriched` and
      `events_expanded`, the ClickHouse RW shadows, the ClickHouse Go-path
      tables as the baseline, and `GET /current_usage`. Details and caveats in
      `loadtest/README.md`.

      Measurement design — two mechanisms deliberately kept apart:
      - POLLED end-to-end: both endpoints read from the app's own clock, so no
        cross-cloud skew enters. Probes are polled as a COHORT (one query per
        stage per tick for the whole in-flight set), because there is no index
        on `transaction_id` in the RisingWave tables. ClickHouse lookups are
        narrowed to the run's subscriptions/codes/time window so they use the
        primary key — without that, the 240M-row production
        `events_enriched_expanded` times out and the stage silently reports
        nothing. No `FINAL` anywhere in the measurement path (existence is
        existence, `min(enriched_at)` is the first insert, `uniqExact` dedupes).
      - STAMPED per-hop: `ingested_at` → `kafka_timestamp` → `rw_received_at` →
        `enriched_at`, covering every event. Spans machine clocks, so the
        measured offsets are DISPLAYED and negative durations flagged as
        artifacts rather than silently corrected.

      Events are spread across every charge filter value, the default bucket
      (no-match properties) and each pricing-group-key value, so
      `filter_match_score`, the default-bucket fallback and `extract_grouped_by`
      are all exercised. Verified: 120 events over 7 shapes resolved into
      exactly 7 distinct `(code, charge_filter_id, grouped_by)` rows in
      `events_expanded` and 7 matching `usage_buckets_15m` rows.

      First local comparison, same events: RisingWave path ingest→ClickHouse
      **224 ms p50** vs the Go events-processor **4279 ms p50**.

      Configuration lives in the app's Setup screen, stored in local SQLite
      (`node:sqlite` — no dotfile, no native module); an existing `.env` is
      imported once and renamed.

- [x] **Stage-1+2 clock added to `events_expanded`** (2026-08-24), closing the
      last gap in the per-hop breakdown. The table now carries `kafka_timestamp`
      and `rw_received_at` through from stage 0, plus `rw_expanded_at` — and
      both are sunk into the ClickHouse expanded shadow (`rw_enriched_at`,
      `rw_expanded_at`), so stage timings are queryable in ClickHouse directly,
      not only through the load-test app.
      - HOW, because the obvious routes are closed: `proctime()` is rejected
        outside CREATE TABLE/SOURCE, and a bare `now()` in a streaming
        projection is rejected too ("only allowed in WHERE, HAVING, ON and
        FROM"). The one position RisingWave will evaluate it per row is a COLUMN
        DEFAULT — so `rw_expanded_at TIMESTAMPTZ DEFAULT now()` on the table,
        with `events_expanded_load` listing its target columns explicitly and
        omitting that one. Adding the column needs the events_expanded subtree
        rebuilt (drop + reapply, re-backfills from `events_enriched`).
      - FIRST RESULT: for live events `rw_received_at == rw_expanded_at` on every
        row (60 events across 25 distinct barriers, zero differing) — the
        billable-metric join, subscription/charge/filter resolution and ranking
        all complete WITHIN ONE BARRIER. The RisingWave leg's cost is the sink +
        ClickHouse insert (p50 362 ms, p95 466 ms), not the compute. Falsified
        that the two columns are not an echo of each other: backfilled rows show
        `rw_enriched_at` from 08-21 against `rw_expanded_at` from the rebuild.
      - CAVEAT: `now()` is the BARRIER timestamp, so the resolution is
        `barrier_interval_ms` (250 ms dev / 1 s default). A 0 on the
        enrich→expand leg means "same barrier", not "instant".

- [ ] **Observability for the flip decision**:
      - persist parity-check results to a table + Grafana panel (logs today)
      - parity at per-filter/per-group granularity (charge totals today)
      - wallet-balance parity check
      - realtime-vs-fallback counters in the realtime aggregators
      - consumer-lag panel for `wallet_refresh_triggers`

### Dedup retention: "is this event already ingested?" — mechanisms measured 2026-08-20

Goal discussed with Jeremy: RisingWave is the single source of truth for
event deduplication (ClickHouse stays a plain MergeTree receiving unique rows
only), answering yes/no on the production ReplacingMergeTree key
(organization_id, code, external_subscription_id, timestamp, transaction_id)
over a 32-day window. Verdict: the yes/no part is easy; **a bounded 32-day
dedup is not expressible in v3.0.2 without paying one of three costs.** All
four mechanisms were measured live, not reasoned about:

| mechanism | bounds state? | cost |
|---|---|---|
| `DISTINCT ON` → `StreamAppendOnlyDedup` | **no** | output stays append-only (joins keep `append_only: true`), but state is never cleaned |
| event-time `WATERMARK` on the source | **no** | compiles to `StreamWatermarkFilter`, which silently DISCARDS late events |
| temporal filter on `kafka_timestamp` before the dedup | **yes** | dedup becomes `StreamGroupTopN`: demotes the stage-1 temporal joins AND leaks expiry DELETEs downstream |
| bounded dedup + `SINK … force_append_only INTO` append-only table | **yes** | ~~trailing-flush buffer~~ FALSIFIED 2026-08-21: measured 131ms cold / 321ms after 60s of silence — the trailing-flush class applies to Kafka sinks, NOT internal-table sinks. **This is the viable design (Jeremy's proposal, see below).** |

Measurements behind those rows:

- `StreamAppendOnlyDedup` does **not** clean state by watermark, even with the
  watermark column as the LEADING column of its state table (the structural
  precondition for range cleaning). Test: 1-minute watermark, watermark
  advanced to 15:37:48, oldest dedup key still 15:22:48, 5/5 keys resident
  after 25s. Its internal state table also stores the **full row**
  (`$expr1, organization_id, code, external_subscription_id, transaction_id,
  properties, ingested_at, _row_id, …`), not just the key — so "unbounded
  dedup" means retaining every event ever seen, in state.
- The event-time watermark is an input **filter**, not a state bound: two late
  events (1 min and 30 min behind the watermark) never reached the MV
  (`late_rows_kept = 0`). It is also driven by CUSTOMER-SUPPLIED timestamps,
  so a single future-dated event advances the watermark and starts discarding
  legitimate traffic. Unusable for billing.
- The temporal-filter form does bound state (`StreamDynamicFilter …
  cleaned_by_watermark: true`) but its expiry DELETEs propagate into
  `usage_realtime` (units decrement) and into `usage_hourly`'s ClickHouse
  upsert sink (deletes dashboard history) — the reason the 32-day filter
  currently lives only in the CH shadow branch, where `force_append_only`
  drops the retractions.

Current shape on the branch (2026-08-21): one shared append-only dedup in
stage 0 keyed on **exactly the prod RMT key** — the CH branch is a bare
projection + 32-day temporal filter, no collapse of its own.

- [x] **Decision — dedup key (2026-08-21).** Jeremy: events are immutable,
      `reprocess` is unused and will stay unused — "it does not make sense to
      reprocess an event". So: bare RMT key, first ingestion wins forever,
      RisingWave is the single source of truth on event identity, and
      `reprocess` is stripped everywhere (source struct, enrichment,
      events_expanded's whole `latest_delivery` correction stage, the
      shadow's `NOT reprocess` filter + first-delivery collapse). There is NO
      in-stream correction path anymore — a re-sent transaction_id is
      silently dropped; corrections are business objects (void + new event,
      credit notes). Consequence for state TTL below: the dedup state is
      key-only lookups now, but still unbounded.

### Applied live 2026-08-21 (stage-0 restructure, then bucket rework, same day)

Everything above is LIVE in dev. History of the day, compressed: the
shared-stage-0 + reprocess-removal topology was applied first (full teardown,
PG reshaped to the scoped `subscription_billing_periods`, validated e2e with
dup/re-ingest collapse and an 806ms→619ms wallet path); the 15-minute bucket
rework then REPLACED the period machinery entirely the same day (periods
table/model/service/clock job deleted on the api branch, Postgres
projections table deleted, `usage_realtime`/`usage_hourly`/`usage_serving`
MVs replaced by `usage_buckets_15m` → CH). Earlier EXPLAIN validation
(2026-08-20) still holds for what remains: stage-1 temporal joins plan
`append_only: true` off the deduped stage 0.

## 2. Prod shadow

- [ ] Deploy real RisingWave cluster in cloud (object store, Prometheus via
      `--prometheus-listener-addr`, decide `barrier_interval_ms` — 1s default
      vs 250ms ≈ 200ms visibility, measured).
- [ ] Run dark: parity flag on, read flags off, across ≥1 full period
      rollover per billing_time flavor. Deployment ordering: api migrations
      before `setup.sh` (sinks validate target tables); add new CDC tables to
      `rw_publication`; consumer needs `LAGO_RISINGWAVE_USAGE_ENABLED`.
- [ ] **`current_usage` is served from the charge cache unless the charge is
      realtime-eligible — found 2026-08-24 on the staging load test, and it is a
      CUTOVER blocker, not an app problem.** `app/services/realtime_usage.rb`
      requires `LAGO_RISINGWAVE_USAGE_ENABLED=true` plus count/sum, in arrears,
      non-prorated, non-recurring, no custom expression; otherwise
      `customer_usage_service.rb:138` leaves the per-charge cache ON, and its
      invalidation is driven by the LEGACY events consumer. Consequence measured
      on staging: 1000 events at 45/s, and `current_usage` did not move for the
      whole 36 s run, then jumped once — every "usage latency" in that run was
      one cache refresh, which reads as a perfectly linear ramp (min 10 s, p50
      20 s, max 30 s). So the pipeline can serve buckets in ~200 ms while a
      customer still sees minutes-old usage, because the read path in front of
      it is cached and invalidated by the component being replaced.
      - What to decide before prod: which charges are realtime-eligible (the
        gate is narrow), and what invalidates the cache for the ones that are
        not once the Go processor is retired.
      - The load-test app now refuses to misreport this: a preflight CANARY
        sends one event and fails the run if `current_usage` does not move
        within 15 s (naming this cause), and a reading-advance verdict
        (`incremental` / `coarse` / `batched`) banners the numbers when one
        reading accounted for many events. Falsification-tested both ways
        against a stub: frozen reads → canary FAIL + `batched` (100 events in
        one reading); live reads → canary PASS (`units 0 → 1 in 263 ms`) +
        `coarse`, usage p50 14 ms.
      - Usage attribution keys on `units` against the exact unit total the run
        has sent (exact for count/sum), with EXACT mode when the probe target is
        free of bulk traffic and WATERMARK mode when it is not — the latter is
        what makes the measurement possible at all on an instance with a single
        subscription and metric. Polling is pipelined and the crossing is
        bracketed between the last "not yet" request and the first "seen"
        response: measured uncertainty ±974 ms → **±174 ms** against a ~1.1 s
        `current_usage`.

- [ ] Flip order after clean parity: current usage reads → wallet trigger
      consumer → alerts.

## 3. Coverage expansion (parallel-friendly)

- [ ] **lago-expression WASM UDF** (crate is already Rust) — biggest
      eligibility widener; until then expression BMs fall back.
- [ ] **Alerts/threshold crossings detected IN RisingWave**, not the trigger
      consumer: CDC the wallet balances/ledger, join against the running
      bucket aggregation, emit a trigger ONLY on a crossing. Trigger volume
      becomes ∝ crossings/s instead of events/s.
- [ ] **Compute-on-read wallet display** (`Wallets::OngoingBalanceCalculator`
      from CH buckets) — display freshness without waiting for the consumer;
      per-event wallet work drops to zero.
      - BUILT AND REVERTED 2026-08-24. It works (verified live: computed ==
        persisted exactly, 511 ms cold / 0 ms memoized per customer per
        request, nothing written on read) but it solves the wrong half. The
        `UPDATE` is microseconds; the cost is `Invoices::CustomerUsageService`
        over every subscription, and that is paid by the CONSUMER deciding to
        refresh, not by the write. Moving display off the columns therefore
        removes no per-event Ruby work at all — it only strands the columns,
        whose only remaining readers are the three PUSH side effects
        (`Wallets::ThresholdTopUpService`, the two ongoing-balance alerts, the
        `wallet.depleted_ongoing_balance` transition). None of those can move
        to read time: nobody is reading, and a threshold top-up that fires
        when someone opens the wallet page is not a top-up.
      - So the lever is CADENCE, not persistence. In order of work:
        (1) skip customers with no side effect to fire — but the depletion
        webhook nominally applies to every wallet, which is what forces
        refreshing everyone, so this needs a product call first;
        (2) debounce per customer on `last_ongoing_balance_sync_at` — makes
        cost O(distinct wallet customers / N) instead of O(events), fully
        decoupled from event rate (at the measured ~20 refreshes/s per 6
        partitions, N=30 s sustains ~600 distinct wallet customers at ANY
        event rate); N is then the worst-case lateness of a top-up;
        (3) the RW-side crossings below — the real fix.
      - If it is ever revived: the computed values MUST be cast the way the
        columns cast them (bigint `.to_i`, decimal(30,5) `.round(5)`), or the
        flag silently flips `credits_ongoing_balance` from a JSON string to a
        number. And `Types::CustomerPortal::Wallets::Object` is a second
        display path that is easy to miss.

  ^ These two together ARE the high-scale wallet plan (discussed 2026-08-21,
  Jeremy's 100K RPS / 100K distinct customers scenario): the per-event
  trigger consumer is the only per-event Ruby component left, and inline
  refresh (~300ms/customer, serialized per partition) caps out at ~20
  distinct customers/s per 6 partitions — partitioning cannot cover a
  100K-distinct-customers/s regime (~30K consumer-cores). At that scale the
  materialized-balance-refresh model is retired: balance = compute-on-read
  over buckets, push = RW-side threshold crossings, and the per-event
  consumer demotes to a debounced reconciliation net (it remains correct and
  load-tested for shadow/early-prod volumes, scaling linearly with
  partitions until then).

  ORDERING, corrected 2026-08-24 by building the compute-on-read half and
  reverting it (see its entry above): the two are NOT interchangeable halves.
  The crossings + debounce are the load-bearing part — they are what removes
  per-event Ruby work. Compute-on-read is a DISPLAY concern only: on its own
  it removes zero per-event work, because the cost lives in the consumer's
  decision to refresh, not in the write. It becomes necessary only once the
  refresh cadence is already decoupled from the event rate and the columns
  are consequently too stale to display. So: crossings/debounce FIRST,
  compute-on-read only if display freshness then demands it.
- [ ] Demote clock sweeps (wallet refresh, daily usage) to slow
      reconciliation nets; `daily_usages` batch job replaceable by a rollup
      of ClickHouse `usage_buckets_15m`.
- [ ] Remaining eligibility: pay-in-advance, prorated; `unique_count` is the
      natural next aggregation (RW does exact incremental distinct).
- [x] Plain `events_enriched` shadow (2026-08-17, restructured 2026-08-20):
      `events_enriched` is now the SHARED stage 0 in `sql/04_enrichment.sql`
      (BM-only inner temporal join + delivery dedup) feeding both the expanded
      path and `events_enriched_rw_shadow` in `sql/10_enriched_shadow.sql`
      (NOT-reprocess filter, 32-day temporal filter on `kafka_timestamp`,
      first-delivery collapse on the prod ReplacingMergeTree key) sinking
      append-only into plain-MergeTree CH `events_enriched_rw_shadow`
      (`clickhouse/events_enriched_rw_shadow.sql` — dedup lives in RW, CH keeps
      full history). Validated 2026-08-18 (parity, dedup, ~318ms).
      SIMPLIFIED 2026-08-24: the intermediate `events_enriched_rw_shadow` MV
      (a residue of the pre-firewall topology, where `events_enriched` was
      itself that file's MV) is GONE — the sink is a bare projection read
      straight off the `events_enriched` table, with no temporal filter (no
      operator state to sweep; `retention_seconds` bounds the table) and no
      `force_append_only` (an append-only upstream binds on its own, so a
      future retracting operator now fails loudly at CREATE SINK instead of
      being laundered into duplicate rows). Parity re-verified 20/20 rows.
- [x] Expanded shadow moved from Kafka to ClickHouse (2026-08-24). The
      `events_enriched_expanded_shadow` topic and its Go-`EnrichedEvent`-shaped
      JSON are gone; `events_enriched_expanded_rw_shadow_sink` writes
      `clickhouse/events_enriched_expanded_rw_shadow.sql` instead — production
      `events_enriched_expanded`'s own column names, PRIMARY KEY and ORDER BY,
      as a plain MergeTree (dedup is upstream, so duplicates must show, not
      collapse). Parity diffing is now a SQL join instead of a topic diff, and
      it immediately showed the expected first-wins/last-wins split: the three
      08-21 dedup probes hold RisingWave's FIRST ingestion while prod
      ReplacingMergeTree + FINAL serves the LAST (`999`). Fallout handled:
      `pipeline_latency_e2e` and the `events_enriched_shadow_loopback` source
      are deleted — e2e latency is now `dateDiff(ingested_at, enriched_at)` in
      ClickHouse (query in `sql/07_observability.sql`), which measures serving
      visibility rather than topic append.
      - [ ] `benchmark/load/sampler.sh` and `benchmark/full_path_benchmark.sh`
            still read the retired topic's high-watermark and
            `pipeline_latency_e2e`. Both were ALREADY stale from the bucket
            rework (they query the deleted `usage_realtime_projections`), so
            they need one pass together, not a patch each.
- [ ] `events_charged_in_advance` sink — with the above, what remains to
      retire the Go processor entirely.

## Load-test finding (2026-08-08) — RESOLVED 2026-08-10 (consumer side)

At per-event trigger volume (~500 ev/s) the wallet trigger consumer fell
behind: peak lag 46k on 2026-08-08 (RAM-swap tainted), 98k on the clean
2026-08-10 rerun — structural. Enrichment and usage layers absorbed the
load both times (e2e ~15ms avg, usage rows ~140ms, projections 0s stale).

The sink stays PER-EVENT; the fixes are consumer-side (see
09_wallet_triggers.sql header for why RW-side coalescing was tried and
reverted — GroupTopN over the updating events_expanded, temporal-join
wallet filter, and TUMBLE+EOWC are all unusable here):
 1. karafka.rb max_messages 500 → 10_000 — batch-collapse costs O(distinct
    customers), so the batch must scale with the backlog or each poll pays
    a full refresh cycle for a thin slice of stream and the consumer can
    never catch up.
 2. WalletRefreshTriggersConsumer skips customers without an active wallet
    (one indexed exists-check per distinct customer per batch) — in the
    load population 90% of triggers are for wallet-less customers.
 3. Wallets::RealtimeRefreshService projection wait wrapped in `uncached`:
    Karafka consumes inside the Rails executor (AR query cache ON), so the
    identical wait query was replayed from cache and could only time out
    unless the projection won the race to the FIRST check. This was the
    real cause of the "bimodal" wallet latency (0.4-1.1s vs ~5.3s) — not
    the PG sink trailing flush, which measures ~300ms for isolated rows.

Measured after fixes (probe = event -> ongoing_usage_balance_cents
reflects it, benchmark/load/wallet_latency_probe.sh):
 * quiet: median 886ms (14/16 probes 0.5-1.8s)
 * under 500 ev/s: median 7.2s, p95 8.2s, 14/14 — pure cycle time
   (~21 wallet customers × ~300ms inline refresh per collapse cycle);
   consumer lag stays bounded (~5k) and drains.

Open items:
 * RESOLVED 2026-08-18: the quiet-stall (~16% of probes, no balance change
   for 30s+) was NOT a cache hole — the realtime projection read path never
   engaged through the production flow at all. Fees::ChargeService#aggregator
   hands aggregators a boundaries hash keyed :from_datetime (already the
   charges window start), but ProjectionLookup#boundaries_agree? only read
   :charges_from_datetime → nil → every lookup silently fell back to the
   ClickHouse events store. The benchmark (and the realtime specs) passed
   :charges_from_datetime in their own hashes, masking the bug: benchmarked
   numbers measured the projection path, production always read ClickHouse.
   The stall = trigger-driven refresh racing the CH Kafka-consumer flush
   (event not yet CH-visible → unchanged balance; next trigger covers it
   under load, which is why the tail vanished at 500 ev/s). Fixed in
   projection_lookup.rb (accept :from_datetime), spec updated to use the
   production hash shape. Verified live: event -> wallet 806ms with the
   balance computed from projections.
 * Under-load cycle latency scales with active wallet customers per
   consumer: parallelize across the 6 partitions (customer keying already
   guarantees per-customer ordering) and/or make the refresh itself cheaper.
 * Gotcha: replacing the sink replays the full events_expanded snapshot
   into the topic (~390k stale triggers) — seek the consumer group to end
   after any sink recreation.
 * Measurement gotcha: `timeout N docker exec rpk consume | grep -m1`
   reports its own timeout, not arrival (the pipeline only exits when rpk
   dies). Use broker timestamps (%d) vs payload watermark instead.
Full data: benchmark/load/.

## Local env note (2026-08-17, resolved 2026-08-18)

The local RisingWave catalog was found EMPTY (state lost at some restart).
Rebuilt 2026-08-18 via `setup.sh` (all 34 streaming jobs CREATED, CDC
snapshots verified, enriched shadow applied and validated). Volume loss also
reset the persisted system params — re-applied `ALTER SYSTEM SET
barrier_interval_ms TO 250` and `sink_decouple TO false`, and recreated all
external sinks (sink_decouple is captured at CREATE SINK time). Safe because
the events-raw source starts at `latest` and all event-derived MVs were
empty (no snapshot replay). `usage_realtime_projections` was truncated: its
pre-wipe rows would otherwise serve values RisingWave no longer backs (the
missing-row fallback to ClickHouse is the designed recovery). Consequence of
`latest` + wipe: projections only cover post-rebuild events, so wallet
balances computed from projections dropped to post-rebuild usage — expected
in dev. Related dev fix: events-processor `.air.toml` now sets `rerun =
true` — after a Docker daemon restart (`restart: unless-stopped` ignores
depends_on ordering) the Go processor could panic on an unreachable
Redpanda and air left a dead process behind a healthy-looking container.

## 4. Process

- [ ] Split branches into reviewable PRs: CH buckets table + read path →
      wallet refresh (the billing-periods PR is obsolete — deleted).

## Resolved 2026-08-21: Postgres sink trailing-edge flush latency

OBSOLETE — the `usage_projection_pg_sink` was deleted with the bucket rework.
Kept for the record: the PG upsert sink (from an updating MV) delayed the
flush of an isolated trailing change by seconds to tens of seconds when the
stream went idle (not fixed by `sink_decouple = false`, RW v3.0.2). The
ClickHouse upsert sink that replaced it does NOT exhibit this (measured:
~300ms trailing flush after 60s of silence); the watermark wait in
`Wallets::RealtimeRefreshService` now polls ClickHouse and exists only to
cover cross-sink epoch ordering, not trailing-flush stalls.

## Known gotchas (hard-won, do not rediscover)

- `CREATE MATERIALIZED VIEW ... IF NOT EXISTS` **binds the query first**: RisingWave
  binds before honoring IF NOT EXISTS, so re-running `setup.sh` after
  reshaping an MV fails on the OLD catalog entry instead of no-op'ing.
  Symptom when `events_enriched` changed shape: `Failed to bind expression:
  e.properties` / `missing FROM-clause entry for table "e"` — which means the
  qualified column did not resolve, NOT that the alias is unbound. Fix: tear
  the chain down (sinks first, then MVs leaves→root) before re-applying.
- CDC table column mismatch reports as `The publication 'rw_publication' does
  not cover all columns of the table` even when the publication covers every
  column (`pg_publication_rel.prattrs` IS NULL). It really means the columns
  you DECLARED do not exist upstream — check `information_schema.columns`
  before blaming the publication.
- Internal state tables are introspectable, which is how state growth /
  cleaning claims should be verified: `SELECT name FROM rw_internal_tables`
  then `SELECT count(*) FROM __internal_<mv>_<id>_<executor>_<n>` (quote
  generated columns as `"$expr1"`).
- `psql` is NOT in the RisingWave image — use the Postgres dev container:
  `docker exec -i lago_db_dev psql -h risingwave -p 4566 -U root -d dev`
  (this is what `setup.sh` falls back to). `\d` fails there on a COLLATE
  feature gap; use `information_schema.columns` instead.
- Temporal joins: RHS must be a TABLE (sink-into-table for derived relations
  like flat_filters). A non-append-only LHS is *accepted* by v3.0.2 but plans
  `append_only: false` with an extra memo table, and lands in the same
  trailing-flush buffering class as the reverted wallet-trigger refinements —
  keep the LHS append-only. `SELECT DISTINCT ON (...)` plans as
  StreamAppendOnlyDedup and PRESERVES append-only across the MV boundary;
  `ROW_NUMBER() OVER (...) = 1` plans as StreamGroupTopN and does not (verified
  by EXPLAIN, 2026-08-20). So dedup can precede a temporal join only in the
  DISTINCT ON form.
- `force_append_only` does NOT just drop updates — `src/stream/src/executor/
  sink.rs` drops `Delete`/`UpdateDelete` and **rewrites `UpdateInsert` into
  `Insert`**. Laundering an updating stream through it therefore turns every
  rank/aggregate change into an EXTRA APPENDED ROW, and every rank loss into
  a silently missing row. Only ever point it at a stream whose only
  retractions are whole-partition expiries (see §0 — this cost a
  double-billing and a silent-event-loss bug on 2026-08-23).
- Kafka sinks: `force_append_only` silently DROPS updates; but upsert sinks
  from updating MVs buffer the trailing per-key change (isolated events
  delivered 30–90s late). For triggers, prefer per-event append-only sinks
  from the append-only stream and coalesce in the consumer.
- Karafka defaults `max_wait_time` to 1000ms — sparse-topic consumers add up
  to 1s batching wait; set ~100ms per topic (no-op under load, batches fill
  via max_messages).
- `proctime()` is barrier-aligned (up to 1s early) — never use for latency;
  measure from Kafka broker timestamps via topic loopback.
- JSONB can't be in a streaming group key (group on `::VARCHAR` rendering).
- Every ClickHouse `usage_buckets_15m` query must lead with
  `organization_id` — it is the first ORDER BY column, so filtering on
  `subscription_id` alone uses no index at all (3.65M rows vs 8.2k for the
  same wallet watermark poll). Cost is invisible in dev, where one org owns
  every row. See §0b.
- A ClickHouse partition key cannot be ALTERed in. Changing it means
  CREATE new + INSERT SELECT ... FINAL + `EXCHANGE TABLES` + DROP. The
  RisingWave ClickHouse sink survives that (it inserts by name over HTTP,
  and EXCHANGE is atomic) — no sink teardown needed.
- Charge cache must stay bypassed for realtime-eligible charges — legacy
  invalidation races the trigger (stale-cache bug found live).
- Wallet refresh serialization unit is the CUSTOMER (cascade covers all
  wallets) — key trigger topics by (organization_id, customer_id).
- `rw_publication` is per-table: new CDC tables need
  `ALTER PUBLICATION ... ADD TABLE`.
