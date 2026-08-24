# RisingWave realtime events pipeline (PoC)

Event-driven enrichment + realtime usage aggregation for count/sum billable
metrics, running in shadow next to the Go events-processor. Goal: replace the
expire-cache → recompute-in-ClickHouse loop (current usage, wallet ongoing
balance, alerts) with continuously-maintained materialized views, and
eventually consolidate dedup + enrichment into the same stack.

## Run it

```sh
docker compose -f docker-compose.dev.yml up -d risingwave
./extra/risingwave/setup.sh        # idempotent, re-run any time
```

- SQL console: `psql -h localhost -p 4566 -d dev -U root`
- Dashboard UI: http://localhost:5691 (also https://risingwave.lago.dev via traefik)
- Dev Postgres credentials are hardcoded in `sql/01_cdc_dimensions.sql`.

## Pipeline

```
events-raw (Kafka) ──────────────┐
                                 ▼
Postgres ──CDC──► billable_metrics / subscriptions / charges / charge_filter* 
                                 │
              flat_filters_mv ──sink-into-table──► flat_filters (temporal-joinable)
                                 │
   [BM join → 32d filter → first-wins dedup]  (bounded: expiry retractions
        │                                      sweep the operator state)
        ▼ force_append_only sink (drops the retractions)
   events_enriched    APPEND ONLY TABLE, retention 33d — retraction firewall,
        │             single entry point for every event-derived relation
        ├──sink──► ClickHouse events_enriched_rw_shadow   (bare projection,
        │                                                  no MV, no filter)
        ▼
   [subscriptions + flat_filters temporal joins → 32d filter → ranking]
        ▼ force_append_only sink
   events_expanded    APPEND ONLY TABLE, retention 33d — one row per
        │             (event, best charge/filter), default-bucket fallback
        ├──► usage_buckets_15m ──► ClickHouse usage_buckets_15m (API reads)
        └──sink──► ClickHouse events_enriched_expanded_rw_shadow
                                          parity diffing vs Go output (SQL join)
```

RisingWave holds a ~32-33 day working set everywhere (dedup answers "already
ingested?" over 32 days); ClickHouse keeps the forever-history. The tables
are retraction FIREWALLS: each stage's 32-day temporal filter emits expiry
DELETEs that clean that stage's own operator state (retraction-driven), and
the force_append_only sink drops them so downstream never decrements. Table
retention_seconds reclaims old rows physically WITHOUT emitting changelog
events (canary-verified: a counting MV over a retention table never
decrements when rows are reclaimed).

| File | Contents |
|---|---|
| `sql/00_source_events_raw.sql` | Kafka source on `events-raw` (starts at `latest`) |
| `sql/01_cdc_dimensions.sql` | Native Postgres CDC source + dimension tables + lookup indexes (replaces BadgerDB cache + Debezium) |
| `sql/02_flat_filters.sql` | Rebuild of the Postgres `flat_filters` view; MV → sink-into-table so it can be temporal-joined |
| `sql/03_functions.sql` | Embedded JS UDFs: `filter_match_score` (mirrors `MatchingFilter`/`IsMatchingEvent`), `extract_grouped_by` |
| `sql/04_enrichment.sql` | Bounded pipeline: sink (BM join → 32d filter → first-wins dedup) INTO append-only TABLE `events_enriched` (retention 33d) → sink (temporal joins → 32d filter → ranking) INTO append-only TABLE `events_expanded` (retention 33d) |
| `sql/05_usage.sql` | `usage_buckets_15m` MV: count/sum per (sub, charge, filter, grouped_by) on 15-minute buckets of the event timestamp — serves current usage AND dashboard history; the API sums buckets over the Rails-computed period window (no period rows anywhere) |
| `sql/06_sinks.sql` | Shadow Kafka sink shaped like the Go `EnrichedEvent` JSON (+ `ingested_at` for latency measurement) + `usage_buckets_clickhouse_sink` upsert into ClickHouse `usage_buckets_15m` (table owned by an api clickhouse migration; ReplacingMergeTree(ver, is_deleted), query with FINAL) |
| `sql/07_observability.sql` | Per-minute latency MVs: `pipeline_latency` (ingest → Kafka), `usage_latency` (ingest → bucket row emitted). e2e (ingest → enriched row queryable) is a ClickHouse query over `events_enriched_expanded_rw_shadow` — the query is in the file |
| `usage_latency_probe.sh` | Measures ingest → *queryable in `usage_buckets_15m`* over pgwire (checkpoint visibility included) |

## Design invariants

- **Events are immutable — first ingestion wins, over a 32-day window.**
  Stage 0 dedups on exactly the production ReplacingMergeTree key
  `(org, code, external_subscription_id, timestamp, transaction_id)`: any
  re-send of the same transaction — Kafka redelivery, client retry — is
  dropped for 32 days (a re-send later than that lands as a new row; the
  window is the contract). RisingWave is the single source of truth for
  "already ingested?". There is deliberately no in-stream correction path
  (`source_metadata.reprocess` is not carried); corrections are business
  objects.
- **Retractions stop at the firewall tables.** Inside each bounded stage,
  the 32-day temporal filter's expiry DELETEs are the state TTL (they sweep
  dedup/ranking/join state); the `force_append_only` sink INTO the
  append-only table drops them, so every consumer (temporal joins, buckets,
  ClickHouse) sees a pure append-only stream and history never decrements.
  Temporal joins read the tables with `append_only: true` plans.
- **Every ranking partition key must carry the FULL event identity**
  (`organization_id, code, external_subscription_id, event_ts,
  transaction_id` — the stage-0 dedup key). This is a BILLING-CORRECTNESS
  invariant, not a style choice. `force_append_only` does not merely drop
  retractions: per `src/stream/src/executor/sink.rs`, it drops
  `Delete`/`UpdateDelete` **and rewrites `UpdateInsert` into `Insert`**. So
  any rank change inside a partition is laundered into an extra appended
  row, and any rank loss is laundered into a silently missing row. If a
  partition key is narrower than event identity, two distinct events share
  one top-1 slot and both failure modes become reachable on legal input —
  `index_unique_transaction_id` is `(organization_id,
  external_subscription_id, transaction_id)`, so one `transaction_id` across
  two subscriptions is allowed. Measured consequences before the
  2026-08-23 fix are documented in `ROADMAP.md`; the header of
  `sql/04_enrichment.sql` carries the full reproduction.
- **Time-window predicates stay out of join conditions.** Subscription
  validity at the event timestamp is computed as a flag and resolved by
  ranking, mirroring the Go `FetchSubscription` ordering.

## Changing the pipeline (recreating MVs, sinks, tables)

Nothing here is a live-edit: RisingWave has no `ALTER MATERIALIZED VIEW` and
no way to alter a sink's query, so any reshape is a drop + recreate — and a
recreated job BACKFILLS. What it backfills from decides whether that is safe.

| you recreate | backfills from | result |
|---|---|---|
| MV over `events_expanded` / `events_enriched` | only the rows still retained (≤33d) | aggregate recomputed from a **trimmed** window — see the `ver` trap below |
| sink INTO an append-only table | its full upstream | **every row re-appended.** Measured on a probe: 3 rows in, sink recreated, 6 rows out |
| sink to ClickHouse / Kafka | full upstream MV snapshot | CH upsert is idempotent (same key, new `ver`); Kafka sinks flood their consumers (~390k stale triggers measured once) |
| MV/sink over the shared `events_raw` Kafka source | retained topic history | replays real events through the new chain (this is also the prod-cutover partial-period fix — see ROADMAP) |
| CDC dimension table | Postgres snapshot | safe, full state |

Two traps that are easy to miss:

- **`usage_buckets_15m.ver` is `MATERIALIZED now64(3)`** — wall clock, so the
  LAST write wins regardless of whether it is correct. A rebuilt MV that
  recomputes a bucket from a retention-trimmed `events_expanded` emits a
  *lower* `events_count`/`units` with a *newer* `ver`, and silently
  overwrites correct ClickHouse history. Under-billing, no signal.
- **`ALTER TABLE ... ADD COLUMN` DOES work** on an append-only table that
  already has a sink into it (verified on v3.0.2 — the column is NULL for
  existing rows). But you cannot alter the sink's query, so *populating* the
  new column still requires the sink drop + recreate, i.e. the backfill.

### Playbook: add a field to `usage_buckets_15m` (MV only — no teardown)

```
1. CH   ALTER TABLE usage_buckets_15m ADD COLUMN <new> ...   -- sink ignores it until step 4
2. RW   CREATE MATERIALIZED VIEW usage_buckets_15m_v2 AS ... -- backfills alongside v1, zero downtime
3.      parity-check v1 vs v2 over buckets INSIDE the retention window
4. RW   DROP SINK usage_buckets_clickhouse_sink;
        CREATE SINK ... AS SELECT ... FROM usage_buckets_15m_v2
        WHERE bucket > now() - INTERVAL '30 days';           -- the important bit
5. RW   DROP MATERIALIZED VIEW usage_buckets_15m;
```

Step 4's `bucket` floor is what stops the rebuild from rewriting older
ClickHouse rows with partial recomputes. 30 days sits inside the 32-day
filter / 33-day retention with margin.

### Playbook: add a field to `events_expanded` or `events_enriched`

No shortcut — use `reapply_enrichment.sh`, which drops the target table with
its sink so the recreated sink backfills into an EMPTY append-only table.
Recreating the sink alone would double-count the whole 32-day window.

### Not done yet — hardening worth doing before prod

Deliberately NOT applied (2026-08-23, Jeremy's call: document now, change
later):

- [ ] Make the `WHERE bucket > now() - INTERVAL '30 days'` floor a permanent
      part of `usage_buckets_clickhouse_sink`, not just a migration step.
- [ ] Change CH `usage_buckets_15m.ver` from `now64(3)` to the data-derived
      `last_ingested_at`, so a partial recompute LOSES to the correct row
      instead of winning it.

## Validated end-to-end (dev)

- CDC snapshot + live replication of all six dimension tables.
- `flat_filters` parity with the Postgres view (incl. `__ALL_FILTER_VALUES__`).
- Filter best-match, default-bucket fallback, subscription+plan attachment.
- Dedup of duplicate deliveries and re-ingestions (first ingestion wins).
- Shadow topic receives Go-shaped enriched JSON.

## Metrics & latency

**Grafana dashboards** (provisioned, zero setup):
- `lago-rw-latency` — pipeline latency, throughput, hourly usage.
- `lago-rw-serving` (http://localhost:3001/d/lago-rw-serving) — STALE since
  the 2026-08-21 bucket rework: its panels still query the removed
  `usage_realtime` MV / Postgres projections and need a rebuild against
  `usage_buckets_15m` + the ClickHouse serving table (ROADMAP §1
  observability).

Start it with
`docker compose -f docker-compose.dev.yml up -d grafana`, then open
http://localhost:3001/d/lago-rw-latency (or https://grafana.lago.dev).
Anonymous admin access in dev, auto-refreshes every 10s. Grafana queries
RisingWave directly over pgwire (Postgres datasource → `risingwave:4566`) —
no Prometheus needed for the pipeline metrics. Panels: end-to-end latency,
usage-emit latency, ingest→Kafka, per-minute throughput. Provisioning lives
in `extra/grafana/` (datasource + dashboard JSON, editable in the UI).


- **End-to-end latency** is measured in ClickHouse since 2026-08-24 (the
  expanded shadow sinks there, not to Kafka): every shadow row carries Ruby's
  `ingested_at` and a ClickHouse-stamped `enriched_at`, so
  `dateDiff('millisecond', ingested_at, enriched_at)` over
  `events_enriched_expanded_rw_shadow` gives ingest → enriched-row-QUERYABLE.
  The per-minute query is in `sql/07_observability.sql`; ignore rows inserted
  by a sink backfill. The retired `pipeline_latency_e2e` MV measured ingest →
  topic append instead: **~3–6 ms** of RisingWave processing (Kafka read →
  temporal joins → UDF → ranking → sink), to which the ClickHouse figure adds
  the sink flush (~0.3 s quiet, barrier-bound).
- **Usage latency** has two distinct numbers (both measured in dev):
  - `usage_latency` MV: ingest → updated usage row *emitted* — aggregation
    updates coalesce and flush per epoch, ~65–625 ms observed. Multiple
    events hitting the same usage row within an epoch emit one update.
  - `usage_latency_probe.sh`: ingest → row *queryable* over pgwire. MV reads
    are checkpoint-consistent, so this is dominated by the barrier interval:
    ~890 ms avg at the default `barrier_interval_ms = 1000`, ~195 ms avg at
    250 ms. Tune with `ALTER SYSTEM SET barrier_interval_ms = ...`
    (tradeoff: more frequent checkpoints → more compaction/IO overhead;
    pick deliberately for prod, and note it also paces Kafka-sink dedup
    batching).
- Do NOT measure latency with `proctime()` — it is barrier-aligned and up to
  1 s early (that is why the raw source's `rw_received_at` is excluded from
  the latency math).
- **System metrics**: the dashboard (:5691) shows the streaming graph,
  per-fragment throughput and backpressure. single_node mode does not expose
  a Prometheus endpoint by default; for cloud/prod, run components with
  `--prometheus-listener-addr` (or use RisingWave Cloud's built-in
  monitoring) and scrape barrier latency, source/sink throughput, and
  Kafka consumer lag into the existing Grafana.

## Known gaps / phase plan

**Done — 15-minute bucket keying** (2026-08-21; replaced billing-period keying)
- Usage is keyed by 15-minute buckets of the event timestamp, NOT by billing
  period: the API sums buckets over the window it computes at read time
  (`Subscriptions::DatesService`), so no period rows are maintained, CDC'd or
  pre-provisioned anywhere — the whole `subscription_billing_periods` layer
  (table, model, upsert service, clock job) was deleted. 15 minutes makes
  every timezone's day boundary land on a bucket wall (all real UTC offsets
  are multiples of 15 min). Known sliver: a subscription starting/terminating
  at a mid-bucket time shares its first/last bucket with the neighbour
  period — at most 15 min of events on the first/last day.

**Phase 2 — parity**
- `lago-expression` evaluation as a WASM UDF (crate is already Rust). Until
  then, BMs with a custom expression fall back to the raw `field_name` value.
- Recurring-BM fallback (no sub active at event time → currently-active sub)
  is not implemented.
- Retry semantics: events that miss a dimension (CDC race) enrich with NULLs
  instead of retrying for 12h. Plan: route NULL-enriched rows to an
  `orphaned_events` sink and re-inject after a delay.
- `events_charged_in_advance` sink.
- Dedup/TopN state TTL (bound state to period end + late-event tolerance).
- `DENSE_RANK` in the best-subscription stage falls back to a non-TopN
  operator (planner notice); revisit if it shows up in profiles.

**Done — API serving path** (api branch `feat/realtime-usage`,
reworked 2026-08-21 from Postgres projections to ClickHouse buckets)
- `usage_buckets_15m` MV → ClickHouse upsert sink into `usage_buckets_15m`
  (table owned by api clickhouse migration; api migrations must run before
  `setup.sh` creates the sink, which validates the table). Quiet-tail flush
  measured ~300ms — the CH upsert sink is NOT in the trailing-flush class.
- Realtime count/sum aggregators (`BucketLookup`) sum buckets over the
  Rails-computed charges window, gated by `LAGO_RISINGWAVE_USAGE_ENABLED` +
  eligibility (in arrears, non-prorated, non-recurring, no expression);
  fallback to the events store when no buckets cover the window. NOTE: a
  partially-covered period (pipeline enabled mid-period without topic
  replay) serves a partial total WITHOUT fallback — cut over at a period
  rollover or replay the events topic from period start.
- Hourly parity check (`LAGO_RISINGWAVE_USAGE_PARITY_CHECK_ENABLED`,
  `RealtimeUsage::ParityCheckService`) compares bucket sums vs the
  events-store aggregation per charge over the current Rails-computed period.

**Done — event-driven wallet refresh** (api branch, `sql/09_wallet_triggers.sql`)
- `wallet_refresh_triggers` Kafka sink, FORMAT UPSERT (append-only sinks drop
  updates!), keyed by (organization_id, customer_id): the refresh cascade
  covers all of a customer's wallets, so the customer is the serialization
  unit — one partition per customer, no concurrent refreshes, no PG lock
  contention (validated: 10-event burst → 1 refresh, correct value, ~1.8s).
- `WalletRefreshTriggersConsumer` batch-collapses per customer and calls
  `Customers::RefreshWalletsService` inline (same guards as
  `Customers::RefreshWalletJob`); `target_wallet_code` rides in the payload.
- Realtime-eligible charges bypass the Redis charge cache in current usage —
  the bucket read is the cache; legacy invalidation caused stale reads.
- The consumer waits (bounded 5s) for ClickHouse `usage_buckets_15m` to reach
  the trigger's `last_ingested_at` watermark before refreshing (the Kafka
  trigger races the CH sink of the same epoch). Requires
  `LAGO_RISINGWAVE_USAGE_ENABLED` on the consumer so the refresh reads
  buckets. Measured event → wallet.ongoing_balance updated: **~400 ms** median warm (351–502 ms; bucket visible in ClickHouse ~250 ms — the floor is barrier_interval_ms, keep 250 ms in prod).

**Phase 3 — remaining**
- Compute-on-read ongoing balance for display paths (wallet serializer).
- Alert threshold-crossing actions from the same consumer.
- Demote the wallet clock sweep to a slow reconciliation net.
- Customer-facing usage dashboards read `default.usage_buckets_15m` in
  ClickHouse (any granularity ≥ 15 min recomposes by summing buckets).
  Successor to the daily_usages batch computation.

**Parity-diff normalization notes**
- Go emits `"<nil>"` for a missing sum field; RW emits `null`.
- RW sink serializes timestamps as epoch millis; Go emits RFC3339 strings.
- Go's `events_enriched` (non-expanded) message carries an arbitrary charge's
  info (map iteration order); don't diff those fields.
- `usage_buckets_15m.grouped_by` is the JSONB's text rendering (JSONB can't be
  a streaming group key); cast back with `::jsonb` when reading.

**Ops notes**
- The CDC source owns Postgres replication slot `risingwave_dev`
  (`max_replication_slots = 4` in dev). If you wipe the RisingWave volume
  without `DROP SOURCE lago_pg`, drop the slot manually:
  `SELECT pg_drop_replication_slot('risingwave_dev');`
- Everything is idempotent (`IF NOT EXISTS`); `setup.sh` can be re-applied.
