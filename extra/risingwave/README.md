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
   events_joined      temporal joins (BM, subscription candidates, flat_filters)
        │              — append-only, lookups frozen at event arrival time
        ▼
   events_expanded    best subscription → best filter per charge (default-bucket
        │             fallback) → keep latest delivery per (org, tx, charge)
        ├──► usage_realtime            count/sum per (sub, charge, filter, grouped_by)
        └──► events_enriched_expanded_shadow (Kafka)   parity diffing vs Go output
```

| File | Contents |
|---|---|
| `sql/00_source_events_raw.sql` | Kafka source on `events-raw` (starts at `latest`) |
| `sql/01_cdc_dimensions.sql` | Native Postgres CDC source + dimension tables + lookup indexes (replaces BadgerDB cache + Debezium) |
| `sql/02_flat_filters.sql` | Rebuild of the Postgres `flat_filters` view; MV → sink-into-table so it can be temporal-joined |
| `sql/03_functions.sql` | Embedded JS UDFs: `filter_match_score` (mirrors `MatchingFilter`/`IsMatchingEvent`), `extract_grouped_by` |
| `sql/04_enrichment.sql` | Stage 1 temporal joins (append-only), stage 2 ranking + dedup |
| `sql/05_usage.sql` | `usage_realtime` MV (count/sum, running totals) + `usage_hourly` MV (per-hour time series keyed on event time) |
| `clickhouse/usage_hourly.sql` | ClickHouse serving table (ReplacingMergeTree(ver, is_deleted)) fed by the `usage_hourly` upsert sink — dashboard/analytics history; query with FINAL |
| `sql/06_sinks.sql` | Shadow Kafka sink shaped like the Go `EnrichedEvent` JSON (+ `ingested_at` for latency measurement) |
| `sql/07_observability.sql` | Per-minute latency MVs: `pipeline_latency` (ingest → Kafka), `pipeline_latency_e2e` (ingest → enriched event back on Kafka), `usage_latency` (ingest → usage row emitted) |
| `usage_latency_probe.sh` | Measures ingest → *queryable in `usage_realtime`* over pgwire (checkpoint visibility included) |

## Design invariants

- **Enrich first, dedup second.** Temporal joins require an append-only left
  side, so all lookups happen on the raw stream; ranking/dedup (updating
  streams) come after. This also gives reprocessing the right semantics: a
  reprocessed event re-enriches against *current* dimensions, then replaces
  its old row, and aggregates retract-and-reapply automatically.
- **Duplicates are no-ops, reprocesses are corrections** — both handled by the
  keep-latest-per-`(org, transaction_id, charge)` stage, verified live:
  resending a transaction with a new value moved `usage_realtime.units` from
  42.5 to 100 with `events_count` still 1.
- **Time-window predicates stay out of join conditions.** Subscription
  validity at the event timestamp is computed as a flag and resolved by
  ranking, mirroring the Go `FetchSubscription` ordering.

## Validated end-to-end (dev)

- CDC snapshot + live replication of all six dimension tables.
- `flat_filters` parity with the Postgres view (incl. `__ALL_FILTER_VALUES__`).
- Filter best-match, default-bucket fallback, subscription+plan attachment.
- Dedup of duplicate deliveries; correction on reprocess.
- Shadow topic receives Go-shaped enriched JSON.

## Metrics & latency

**Grafana dashboard** (provisioned, zero setup): start it with
`docker compose -f docker-compose.dev.yml up -d grafana`, then open
http://localhost:3001/d/lago-rw-latency (or https://grafana.lago.dev).
Anonymous admin access in dev, auto-refreshes every 10s. Grafana queries
RisingWave directly over pgwire (Postgres datasource → `risingwave:4566`) —
no Prometheus needed for the pipeline metrics. Panels: end-to-end latency,
usage-emit latency, ingest→Kafka, per-minute throughput, and the most
recently updated `usage_realtime` rows. Provisioning lives in
`extra/grafana/` (datasource + dashboard JSON, editable in the UI).


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

**Phase 2 — parity**
- `lago-expression` evaluation as a WASM UDF (crate is already Rust). Until
  then, BMs with a custom expression fall back to the raw `field_name` value.
- Billing-period keying: Rails maintains a `current_billing_periods` table
  (date logic stays in Ruby), CDC'd + temporal-joined; `usage_realtime`
  currently aggregates everything since pipeline start.
- Recurring-BM fallback (no sub active at event time → currently-active sub)
  is not implemented.
- Retry semantics: events that miss a dimension (CDC race) enrich with NULLs
  instead of retrying for 12h. Plan: route NULL-enriched rows to an
  `orphaned_events` sink and re-inject after a delay.
- `events_charged_in_advance` + plain `events_enriched` sinks.
- Dedup/TopN state TTL (bound state to period end + late-event tolerance).
- `DENSE_RANK` in the best-subscription stage falls back to a non-TopN
  operator (planner notice); revisit if it shows up in profiles.

**Phase 3 — serve from it**
- Wallet ongoing balance MV (usage + credits), alert threshold-crossing MV →
  Kafka → alert worker.
- Rails reads current usage from a Postgres-sunk projection of
  `usage_realtime` (or pgwire) instead of the Redis charge cache; retire the
  refresh-flag / cache-expiry loop for count/sum.
- Customer-facing hourly dashboards read `default.usage_hourly` in ClickHouse
  (validated: hours keyed on event time, backfill included, corrections
  propagate as row replacements — 3 sinks total: Kafka=push, PG=live state,
  CH=time-series history). Successor to the daily_usages batch computation.

**Parity-diff normalization notes**
- Go emits `"<nil>"` for a missing sum field; RW emits `null`.
- RW sink serializes timestamps as epoch millis; Go emits RFC3339 strings.
- Go's `events_enriched` (non-expanded) message carries an arbitrary charge's
  info (map iteration order); don't diff those fields.
- `usage_realtime.grouped_by` is the JSONB's text rendering (JSONB can't be a
  streaming group key); cast back with `::jsonb` when reading.

**Ops notes**
- The CDC source owns Postgres replication slot `risingwave_dev`
  (`max_replication_slots = 4` in dev). If you wipe the RisingWave volume
  without `DROP SOURCE lago_pg`, drop the slot manually:
  `SELECT pg_drop_replication_slot('risingwave_dev');`
- Everything is idempotent (`IF NOT EXISTS`); `setup.sh` can be re-applied.
