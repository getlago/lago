# RisingWave realtime usage — remaining work

State as of 2026-08-07: enrichment + dedup/correction pipeline in shadow,
billing periods, period-keyed `usage_realtime` + Postgres projections, API
read path (count/sum incl. charge filters and pricing_group_keys), hourly
usage → ClickHouse, event-driven wallet refresh, Grafana dashboards
(`lago-rw-latency`, `lago-rw-serving`), latency benchmarks, parity checker.
Branches: meta `poc/risingwave-realtime-usage`, api
`feat/subscription-billing-periods`. Details in `README.md`, numbers in
`benchmark/RESULTS.md`.

## 1. Harden for prod shadow (do first, one chunk)

- [ ] **State TTL** on dedup/TopN state, bounded to period end + late-event
      tolerance (events carry periods now). Blocking for prod volume —
      without it, RisingWave state grows with all-time transactions.
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
      from projections) — display freshness without waiting for the consumer.
- [ ] Demote clock sweeps (wallet refresh, daily usage) to slow
      reconciliation nets; `daily_usages` batch job replaceable by a rollup
      of ClickHouse `usage_hourly`.
- [ ] Remaining eligibility: pay-in-advance, prorated; `unique_count` is the
      natural next aggregation (RW does exact incremental distinct).
- [x] Plain `events_enriched` shadow (2026-08-17): `sql/10_enriched_shadow.sql`
      (`events_enriched` MV: BM-only inner temporal join, NOT-reprocess filter,
      first-delivery dedup on the prod ReplacingMergeTree key, 32-day state
      retention via temporal filter on `kafka_timestamp`) sinking append-only
      into plain-MergeTree CH `events_enriched_rw_shadow`
      (`clickhouse/events_enriched_rw_shadow.sql` — dedup lives in RW, CH keeps
      full history). NOT YET APPLIED locally — pending validation (notably
      RW decimal → CH `Decimal(40,15)` and jsonb→String sink mapping).
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

- [ ] Split branches into reviewable PRs: billing periods (standalone,
      shippable independently) → projections + read path → wallet refresh.

## Open issue: Postgres sink trailing-edge flush latency

The `usage_projection_pg_sink` (upsert sink from an updating MV) delays the
flush of an isolated trailing change by seconds to tens of seconds when the
stream goes idle. Not fixed by `SET sink_decouple = false` at sink creation,
nor `ALTER SYSTEM SET sink_decouple = false` + restart (RW v3.0.2
single-node). Consequences and current state:

- Correctness is protected: triggers carry a per-subscription
  `last_ingested_at` watermark and `Wallets::RealtimeRefreshService` waits
  (5s bound) for projections to catch up; on timeout it refreshes anyway and
  the next event or reconciliation sweep corrects.
- Wallet latency is bimodal: ~0.4–1.1s when the projection flushes promptly,
  ~5.3s when it trails (watermark timeout). The Kafka trigger side was fixed
  by sourcing triggers from the append-only event stream (upsert sinks from
  updating MVs have the same trailing behavior — that was the wallet-trigger
  30–90s bug).
- To investigate: RW GitHub issues / newer versions for upsert-sink flush
  pacing; whether a real multi-node cluster behaves differently; per-sink
  flush knobs. Alternatives if unresolved: raise the watermark timeout, or
  have the refresh read usage over pgwire from `usage_serving` directly
  (checkpoint-consistent read, no sink in the path) for the wallet path.

## Known gotchas (hard-won, do not rediscover)

- Temporal joins: append-only LHS only (enrich first, dedup second); RHS
  must be a TABLE (sink-into-table for derived relations like flat_filters).
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
