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
   events_enriched    BM temporal join + delivery dedup (append-only,
        │             StreamAppendOnlyDedup) — single entry point for every
        │             event-derived relation
        ├──► events_enriched_rw_shadow ──► ClickHouse events_enriched_rw_shadow
        ▼
   events_joined      temporal joins (subscription candidates, flat_filters) —
        │              append-only, lookups frozen at arrival time
        ▼
   events_expanded    best subscription → best filter per charge (default-bucket
        │             fallback)
        ├──► usage_buckets_15m ──► ClickHouse usage_buckets_15m (API reads)
        └──► events_enriched_expanded_shadow (Kafka)   parity diffing vs Go output
```

| File | Contents |
|---|---|
| `sql/00_source_events_raw.sql` | Kafka source on `events-raw` (starts at `latest`) |
| `sql/01_cdc_dimensions.sql` | Native Postgres CDC source + dimension tables + lookup indexes (replaces BadgerDB cache + Debezium) |
| `sql/02_flat_filters.sql` | Rebuild of the Postgres `flat_filters` view; MV → sink-into-table so it can be temporal-joined |
| `sql/03_functions.sql` | Embedded JS UDFs: `filter_match_score` (mirrors `MatchingFilter`/`IsMatchingEvent`), `extract_grouped_by` |
| `sql/04_enrichment.sql` | Stage 0 `events_enriched` (BM temporal join + first-wins dedup), stage 1 temporal joins (append-only), stage 2 ranking |
| `sql/05_usage.sql` | `usage_buckets_15m` MV: count/sum per (sub, charge, filter, grouped_by) on 15-minute buckets of the event timestamp — serves current usage AND dashboard history; the API sums buckets over the Rails-computed period window (no period rows anywhere) |
| `sql/06_sinks.sql` | Shadow Kafka sink shaped like the Go `EnrichedEvent` JSON (+ `ingested_at` for latency measurement) + `usage_buckets_clickhouse_sink` upsert into ClickHouse `usage_buckets_15m` (table owned by an api clickhouse migration; ReplacingMergeTree(ver, is_deleted), query with FINAL) |
| `sql/07_observability.sql` | Per-minute latency MVs: `pipeline_latency` (ingest → Kafka), `pipeline_latency_e2e` (ingest → enriched event back on Kafka), `usage_latency` (ingest → bucket row emitted) |
| `usage_latency_probe.sh` | Measures ingest → *queryable in `usage_buckets_15m`* over pgwire (checkpoint visibility included) |

## Design invariants

- **Events are immutable — first ingestion wins.** `events_enriched` (stage 0)
  dedups on exactly the production ReplacingMergeTree key
  `(org, code, external_subscription_id, timestamp, transaction_id)`: any
  re-send of the same transaction — Kafka redelivery, client retry — is
  dropped. RisingWave is the single source of truth for "already ingested?".
  There is deliberately no in-stream correction path (`source_metadata.
  reprocess` is not carried); corrections are business objects.
- **Dedup must preserve append-only.** The stage-1 temporal joins need an
  append-only left side, so stage 0 dedups with `SELECT DISTINCT ON`
  (plans `StreamAppendOnlyDedup`, append-only in/out) — never
  `ROW_NUMBER()=1` (plans `StreamGroupTopN`, demotes everything downstream
  into the trailing-flush buffering class).
- **Time-window predicates stay out of join conditions.** Subscription
  validity at the event timestamp is computed as a flag and resolved by
  ranking, mirroring the Go `FetchSubscription` ordering.

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


- **End-to-end latency** is self-measured from broker timestamps:
  `select * from pipeline_latency_e2e order by window_start desc;` gives
  ingest → enriched-event-published per minute. Measured in dev:
  **~3–6 ms** of RisingWave processing (Kafka read → temporal joins → UDF →
  ranking → sink → Kafka append).
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
