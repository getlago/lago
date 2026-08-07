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
- [ ] Plain `events_enriched` + `events_charged_in_advance` sinks — only
      needed to retire the Go processor entirely.

## Load-test finding (2026-08-08)

At per-event trigger volume (~500 ev/s) the wallet trigger consumer is the
bottleneck: peak lag 46k messages (drained post-run via batch-collapse).
Enrichment/usage layers absorbed the load (e2e 14ms avg, usage rows ~145ms,
projections 0s stale). Fix candidate that also solves the trailing-edge
issue: emit triggers from a 1s TUMBLE window per customer with EMIT ON
WINDOW CLOSE — append-only (eager delivery, no upsert trailing buffer) AND
coalesced (≤1 msg/customer/second). Also: scale consumer processes across
the 6 partitions. Full data: benchmark/load/.

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
