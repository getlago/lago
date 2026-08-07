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

## 4. Process

- [ ] Split branches into reviewable PRs: billing periods (standalone,
      shippable independently) → projections + read path → wallet refresh.

## Known gotchas (hard-won, do not rediscover)

- Temporal joins: append-only LHS only (enrich first, dedup second); RHS
  must be a TABLE (sink-into-table for derived relations like flat_filters).
- Kafka sinks: `force_append_only` silently DROPS updates — use
  `FORMAT UPSERT` when rows update in place (wallet triggers bug).
- `proctime()` is barrier-aligned (up to 1s early) — never use for latency;
  measure from Kafka broker timestamps via topic loopback.
- JSONB can't be in a streaming group key (group on `::VARCHAR` rendering).
- Charge cache must stay bypassed for realtime-eligible charges — legacy
  invalidation races the trigger (stale-cache bug found live).
- Wallet refresh serialization unit is the CUSTOMER (cascade covers all
  wallets) — key trigger topics by (organization_id, customer_id).
- `rw_publication` is per-table: new CDC tables need
  `ALTER PUBLICATION ... ADD TABLE`.
