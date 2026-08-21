# RisingWave realtime usage — remaining work

State as of 2026-08-21: enrichment with first-wins dedup on the prod RMT key
(events immutable, reprocess removed), usage on 15-minute buckets of the
event timestamp → ClickHouse `usage_buckets_15m` serving table (billing
periods, the period-keyed `usage_realtime` and the Postgres projections were
all DELETED — the API sums buckets over the Rails-computed period window),
API read path (count/sum incl. charge filters and pricing_group_keys),
event-driven wallet refresh with a CH watermark wait, Grafana dashboards,
latency benchmarks, parity checker over the current period. Branches: meta
`poc/risingwave-realtime-usage`, api `feat/subscription-billing-periods`.
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
- [ ] `lago-rw-serving` Grafana dashboard is stale (queried `usage_realtime`
      + PG projections) — rebuild against `usage_buckets_15m` + CH.
- [ ] Boundary sliver (≤15min of events when a subscription starts or
      terminates at a mid-bucket time): accepted for now; if it ever
      matters, query raw events for the two boundary buckets only.
- unique_count cannot recompose across buckets (distinct ≠ sum of per-bucket
  distincts) — needs its own structure when its turn comes (§3).

## 1. Harden for prod shadow (do first, one chunk)

- [ ] **State TTL** on dedup/TopN/bucket-agg state. Blocking for prod
      volume — without it, RisingWave state grows with all-time
      transactions. The rolling-window mechanisms were all measured and
      rejected (see below); note the bucket MV's agg state is time-keyed by
      design, but a temporal filter on it would emit expiry DELETEs into the
      CH upsert sink (is_deleted rows destroying history) — bounding it
      needs the sink to drop deletes or a different retention mechanism.
- [ ] **Orphaned-event re-injection**: sink NULL-enriched rows (no BM /
      no subscription at enrichment time), re-inject into `events-raw` after
      a delay, alert on second orphaning. Replaces the Go processor's
      12h-retry semantics for CDC races.
- [ ] **Recurring-BM fallback** (no active sub at event time → currently
      active sub) in the subscription ranking stage — last enrichment
      difference vs the Go processor.
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
| bounded dedup + `SINK … force_append_only INTO` append-only table | yes | reintroduces the trailing-flush buffer (18–90s idle) — same class as the reverted wallet-trigger refinements |

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
- [ ] Flip order after clean parity: current usage reads → wallet trigger
      consumer → alerts.

## 3. Coverage expansion (parallel-friendly)

- [ ] **lago-expression WASM UDF** (crate is already Rust) — biggest
      eligibility widener; until then expression BMs fall back.
- [ ] **Alerts/threshold crossings** from the trigger consumer (same pattern
      as wallets) — kills the alert polling loop.
- [ ] **Compute-on-read wallet display** (`Wallets::OngoingBalanceCalculator`
      from CH buckets) — display freshness without waiting for the consumer.
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
- Charge cache must stay bypassed for realtime-eligible charges — legacy
  invalidation races the trigger (stale-cache bug found live).
- Wallet refresh serialization unit is the CUSTOMER (cascade covers all
  wallets) — key trigger topics by (organization_id, customer_id).
- `rw_publication` is per-table: new CDC tables need
  `ALTER PUBLICATION ... ADD TABLE`.
