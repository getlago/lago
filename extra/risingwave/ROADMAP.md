# RisingWave realtime usage — remaining work

State as of 2026-08-24 (no pipeline change since 08-23 — the day's api work, compute-on-read wallet balance, was built and reverted; see §3): BOUNDED 32-day pipeline — enrichment runs as two
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
      active sub) in the subscription ranking stage — last enrichment
      difference vs the Go processor.
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
- Charge cache must stay bypassed for realtime-eligible charges — legacy
  invalidation races the trigger (stale-cache bug found live).
- Wallet refresh serialization unit is the CUSTOMER (cascade covers all
  wallets) — key trigger topics by (organization_id, customer_id).
- `rw_publication` is per-table: new CDC tables need
  `ALTER PUBLICATION ... ADD TABLE`.
