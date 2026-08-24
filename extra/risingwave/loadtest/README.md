# RisingWave pipeline — load test & latency dashboard

Sends events to the **Lago API** for existing customers and active subscriptions,
then measures how long each stage of the realtime pipeline takes to catch up:

```
POST /api/v1/events
  ├─ API response                                          (this app's clock)
  ├─ queryable in RisingWave  events_enriched              stage 0
  ├─ queryable in RisingWave  events_expanded              stage 1+2
  ├─ queryable in ClickHouse  events_enriched_rw_shadow            ┐ RisingWave path
  ├─ queryable in ClickHouse  events_enriched_expanded_rw_shadow   ┘
  ├─ queryable in ClickHouse  events_enriched / _expanded          ← Go events-processor, the baseline
  └─ reflected in GET /customers/:id/current_usage         what a customer sees
```

P50 / P95 / P99 for every one of those, live, plus the per-hop breakdown of where
the time actually goes.

## Run it

```bash
cd extra/risingwave/loadtest
npm install
npm run dev               # API on :5180, UI on http://localhost:5181
```

There is **no dotfile to fill in**. Configuration lives in a local SQLite
database (`loadtest.db`, gitignored, via built-in `node:sqlite` — no native
module) and the **Setup screen is the only way in**. A fresh install opens on
Setup, refuses to start a run until the connections are filled in, and stores
what you save immediately. Secrets stay server-side: `GET /api/config` returns
masked values, and a blank secret field means "keep what is stored".

If you already had a `.env` or `config.json` from an earlier version, it is
imported **once** into SQLite and renamed to `*.imported`, so nothing is lost and
there is no second source of truth. Node 22.5+ (developed on 24).

`npm run build && npm start` serves the built UI from the API process on `:5180`.

Then, in the UI: **Setup** (connections, test them) → **Targets** (scan Lago, tick
what to load, pick a usage probe) → **Run** (rate, total, ramp, start).

## Event spread across charge filters and pricing group keys

Sending every event with the same properties leaves most of the pipeline
untested: `filter_match_score` never has to choose between competing charge
filters, the default-bucket fallback never fires, and `extract_grouped_by` only
ever produces one key. So a run expands each selected target into every **event
shape** it can and round-robins over all of them:

- **one shape per charge filter value** — a filter declaring several values for a
  key is one bucket, so coverage needs one shape per value, not the cross product
  (count stays linear in what the plan declares)
- **the default bucket** — properties deliberately matching no declared value, so
  the event is attributed to the charge itself
- **one shape per pricing group key value** — `groupKeyValues` synthetic values
  per key, rotated in lockstep so k keys give N shapes rather than N^k, each
  becoming its own `usage_buckets_15m` row

Controlled on the Run screen (values per group key, whether to hit the default
bucket, a cap per target) and reported in Preflight before anything is sent. The
**Event spread** table then shows what each shape actually sent, so "it spread"
is verifiable rather than asserted.

Verified locally on three metrics of one subscription — a plain count, a
2-filter sum, and a sum grouped by `region` — 120 events over 7 shapes (17-18
each), which the pipeline resolved into exactly 7 distinct
`(code, charge_filter_id, grouped_by)` rows in RisingWave `events_expanded` and
7 matching `usage_buckets_15m` rows in ClickHouse.

## What is actually measured, and how much to trust it

Two independent mechanisms, shown separately on purpose.

**Polled — the trustworthy end-to-end numbers.** Every Nth event becomes a probe
and is looked up at each stage on every poll tick until it appears. Both ends of
the measurement — the moment the POST left, and the tick that first saw the row —
are read from **this app's clock**, so no cross-cloud clock skew can enter. Cost
is flat in probe count: one query per stage per tick covers the whole in-flight
set, never one query per event. The tick (default 200 ms) **is** the resolution;
a value at or below it means "there on the first look".

These numbers include the API round trip, because "the event was sent" is the
question being asked. On a slow API the response time can dominate — compare
`API response` against the rest to see how much of the total is ingest.

**Stamped — the per-hop breakdown.** Every event (not just probes) also carries
the timestamps the pipeline recorded for itself: `ingested_at` (Lago),
`kafka_timestamp` (Redpanda broker), `rw_received_at` (RisingWave),
`enriched_at` (ClickHouse insert). Swept incrementally on a watermark, so cost
stays flat as a run grows. These pinpoint the expensive hop, but **each spans two
machines' clocks** — the Clock offsets panel measures the disagreement, and any
negative duration is flagged as what it is: a clock artifact, not a measurement.
Nothing is silently corrected.

Known limits, all surfaced in Preflight rather than hidden:

- **`events_expanded` now carries its own clocks** (added 2026-08-24):
  `kafka_timestamp` and `rw_received_at` carried from stage 0, plus
  `rw_expanded_at` — the barrier at which stage 1+2 emitted the row. That splits
  the RisingWave leg into *compute* (`rw_received_at → rw_expanded_at`, one clock
  at both ends, so skew-free) and *sink+insert*
  (`rw_expanded_at → enriched_at`). Both are also sunk into the ClickHouse
  expanded shadow, so the same split is queryable there without this app.
  Floor: both stamps are barrier-aligned, so nothing below `barrier_interval_ms`
  (250 ms dev) is resolvable — a 0 means "same barrier", not "instant".
- **No index on `transaction_id`** in the RisingWave tables, so a lookup scans the
  32-day working set. That is why probes are polled as a cohort. ClickHouse
  lookups are narrowed to the run's subscriptions, metric codes and time window so
  they use the primary key — without that, the 240M-row production
  `events_enriched_expanded` times out and the stage silently reports nothing.
- **`rw_received_at` is barrier-aligned** and can read up to one barrier interval
  early, so the `Redpanda → RisingWave` leg is slightly optimistic.
- **No `FINAL` anywhere in the measurement path**, on either the shadow tables or
  the ReplacingMergeTree production ones: existence is existence,
  `min(enriched_at)` returns the first insert regardless of row versions, and
  counts use `uniqExact`. FINAL would force a merge per poll for nothing.

## Usage latency: two attribution modes

`current_usage` exposes no per-event handle, so attribution has to come from the
monotonic `events_count` of one metric. Which mode runs is chosen automatically
and stated in Preflight and on the run.

**Exact** — the probe target carries no bulk traffic. One probe event is in
flight at a time: send → poll until the count reaches the expected value → send
the next. Each measurement belongs to exactly one event. Needs a spare
(subscription, metric) pair.

**Watermark** — the probe target *also* carries bulk traffic. This is the normal
case on an instance with a single subscription and a single billable metric,
where isolation is impossible. Every accepted event for the pair is recorded in
send order; when the count reaches k, that crossing is attributed to the k-th
event sent. All traffic to the pair is this app's, so **k is exact** — only the
crossing-to-event pairing assumes in-order delivery, so read the tail as
indicative rather than per-event truth. In exchange, *every* event yields a
sample instead of just the sampled probes.

Either way the measurement runs *underneath* the bulk load, so the number is
usage latency under load rather than usage latency of an idle system.

### Is the read path even live? (checked before the run)

`current_usage` is **cached per charge** unless the charge is realtime-eligible
(`app/services/realtime_usage.rb`: `LAGO_RISINGWAVE_USAGE_ENABLED=true`, count or
sum, in arrears, non-prorated, non-recurring, no custom expression). When the
cache is in play, invalidation is driven by the legacy events consumer — so under
load the value does not move while events arrive and then jumps once. Every
"latency" in that jump is the same refresh measured from each event's own send
time, which comes out as a suspiciously smooth ramp (min 10 s, p50 20 s, max 30 s
on a 30 s run — this is what the 2026-08-24 staging run hit).

Two defences, so that cannot be mistaken for latency again:

- **Preflight canary** — one event is sent and `current_usage` is polled for up
  to 15 s. If `units` does not move, the run says so up front and names the
  cause. Verified against a stub that freezes its reading: canary FAIL, and
  against a live one: `units 0 → 1 in 263ms, so this read path is live`.
- **Reading-advance verdict** — how many events one reading accounted for.
  `incremental` (steps of 1), `coarse` (a few, poll harder or slow the rate) or
  `batched`, which puts a red banner over the numbers explaining they are a cache
  refresh. Verified: the frozen stub scored `batched` (100 events in one reading,
  50% of the run); the live stub scored `coarse` (worst step 6, 3%) with
  usage p50 14 ms.

Attribution keys on **`units`**, not the event count: the run knows exactly how
many units it has sent, so "has usage reached my expected total?" is an exact
question for count and sum metrics (each event's contribution is read from the
payload it actually sent).

### How hard it polls, and what that buys

`current_usage` is a heavy read — over a second per request against a dev API —
so polling is **pipelined**: a request goes out every `usagePollMs` up to
`usagePollConcurrency` in flight, rather than waiting for each response. The
endpoint's response time therefore no longer sets the sampling rate.

Accuracy comes mostly from **bracketing**, not raw rate. A poll that comes back
still short of event k proves the crossing had not happened when that request
*started*; the poll that does see it bounds the crossing by when that response
*arrived*. The sample is placed in the middle of that window, and half the window
is reported as the measurement's uncertainty — measured per run, not assumed.
Measured locally against a ~1.1 s `current_usage`: serial polling gave ±974 ms,
pipelined + bracketed gives **±174 ms** at the same ~2.5 polls/s.

Raising `usagePollConcurrency` tightens the lower bound but makes
`current_usage` slower — 8 in flight doubled its RTT here, which shifts the
latency being measured. The run shows polls/second, RTT p50/p95 and the
uncertainty side by side so that trade-off is visible rather than silent; the
defaults (100 ms, 4 in flight) are a deliberate middle.

## Guards

Rate, total, optional ramp, `stop above N% errors`, and a hard cap that a typo
cannot exceed. A run also stops early if no probe has made progress for 15 s
rather than waiting out the full probe timeout, and it says which stages it gave
up on.

## Output

Live via SSE, and persisted per run under `runs/<id>/`:

| file | contents |
|---|---|
| `preflight.json` | what was reachable, the clock offsets, the resolved table names |
| `summary.json` | spec, counters, percentiles, histograms, throughput, errors, logs |
| `events.jsonl` | one line per event: send time, API time, per-stage first-seen, every stamp |

`summary.json` is exactly what the dashboard renders, so History replays a past
run through the same view as a live one.

## Layout

```
server/   Fastify. Lago + RisingWave (pgwire) + ClickHouse (HTTPS) clients,
          discovery, run orchestration, cohort pollers, stamp sweeps, SSE.
  src/types.ts     the segment catalog — the UI renders itself from this, so what
                   the dashboard claims and what the server computes cannot drift
web/      React + Vite. Charts are hand-rolled SVG against theme tokens.
```

Chart colors come from a palette validated for colorblind separation and contrast
in both light and dark mode: an ordinal single-hue ramp for P50→P95→P99 (ordered
magnitude, not three unrelated categories), the first three categorical slots for
the hop waterfall, and reserved status colors that are never reused as series
colors.
