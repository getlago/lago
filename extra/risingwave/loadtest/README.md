# RisingWave pipeline — load test & latency dashboard

Sends events for existing customers and active subscriptions — through the **Lago
API**, or straight to **Redpanda** when the API is the throughput ceiling rather
than the thing being measured — then measures how long each stage of the realtime
pipeline takes to catch up:

```
POST /api/v1/events    (or a direct produce to events-raw)
  ├─ API response / produce ack                            (this app's clock)
  ├─ queryable in RisingWave  events_enriched              stage 0
  ├─ queryable in RisingWave  events_expanded              stage 1+2
  ├─ queryable in ClickHouse  events_enriched_rw_shadow            ┐ RisingWave path
  ├─ queryable in ClickHouse  events_enriched_expanded_rw_shadow   ┘
  ├─ queryable in ClickHouse  events_enriched / _expanded          ← Go events-processor, the baseline
  ├─ reflected in GET /customers/:id/current_usage         what a customer sees
  └─ reflected in GET /wallets ongoing_usage_balance_cents what a customer's
       (trigger → consumer batch-collapse → bucket wait → refresh)  credits show
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
what to load, pick a usage probe and a wallet probe) → **Run** (rate, total, ramp,
batch size, start). If the achieved rate flattens well below the target, read
[Reaching the target rate](#reaching-the-target-rate) — it is almost always the
sender's in-flight budget, not the pipeline.

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
(`app/services/realtime_usage.rb`: `LAGO_REALTIME_USAGE_ENABLED=true`, count or
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

## Wallet: is the ongoing balance keeping up?

The wallet is the deepest thing the pipeline drives, and the one with the most
moving parts between an event and what the customer sees:

```
events_expanded → realtime_usage_triggers_sink (one message per event, keyed by
                  organization+customer)
               → WalletRefreshConsumer  (collapses a batch to one refresh
                  per customer; skips customers with no wallet)
               → Wallets::RealtimeRefreshService (waits for usage_buckets_15m to
                  reach the trigger's ingestion watermark, then refreshes)
               → wallets.ongoing_usage_balance_cents
```

Every one of those hops can be the slow one, and three of them can be *broken*
in a way that looks exactly like "the wallet is slow": the consumer not running,
the wallet restricted to metrics the events do not use, or `current_usage` itself
being stale (the refresh reads usage, so a dead usage path is a dead wallet
path). So the wallet measurement is built the same way as the usage one — say up
front what it can claim, then measure it.

Pick a **wallet probe** on the Targets tab: a target whose customer holds an
active wallet, marked with a wallet pill. The reading is the sum of
`ongoing_usage_balance_cents` over that customer's active wallets. Summing is
correct rather than convenient: ongoing usage is allocated across wallets in
priority order and the last applicable wallet absorbs the overflow (it is
allowed to go negative), so the total keeps tracking total ongoing usage even
after an individual wallet's credits run out mid-run.

### Three attribution modes, and what each one is worth

`GET /wallets` exposes no per-event handle either — only a monotonic amount that
the run is the sole writer of. Which mode applies is decided from the traffic and
stated in Preflight and on the run.

**Exact** — the wallet's customer receives only the serial usage probe. One event
is outstanding at a time, so the n-th increase of the balance *is* the n-th
event. No price, no arithmetic, and therefore no charge-model assumptions.

**Watermark** — the customer also carries bulk traffic, and every shape sent to
it is a `standard` charge, so the amount is linear in units and the cents the
reading must reach after k events is predictable. This is the usage watermark
with cents instead of units — and the same code: both run on one
`CrossingTracker`, so "usage latency" and "wallet latency" cannot drift into
meaning different things.

Predicted cents are pre-tax, per event, in plan currency; the reading is a
rounded post-tax total in wallet currency divided by the wallet's rate. None of
that is modelled. Preflight sends one event, measures how far the balance
actually moved, and keeps the ratio — so taxes, the currency subunit and
`rate_amount` are all absorbed by one measured factor, and a factor far from 1 is
itself worth seeing. Verified locally against a customer carrying two metrics
with *different* per-filter prices: 120 of 120 events attributed, factor 1.000.

**Refresh** — the customer carries bulk traffic and at least one shape is not a
standard charge (graduated, package, percentage, volume are not linear in units).
Each observed refresh is then timed against the oldest outstanding event, which
is reported for what it is: an **upper bound**. A refresh coalesces every event
whose bucket had landed, so the events behind it were already covered and get
charged to the next refresh instead. Only standard charges are priced —
guessing a tiered price would silently mis-attribute every sample.

### The coalescing is counted, not averaged away

The consumer collapsing N triggers for one customer into one refresh is the
design, not a defect — so the run reports **refreshes** and **events per
refresh** next to the percentiles. On a local 15/s run: 120 events, 38
refreshes, 3.2 events per refresh.

Refreshes are counted from `last_ongoing_balance_sync_at`, which is touched on
every refresh and therefore moves even when the recomputed amount is identical.
A Lago that does not serialize that field still works — refreshes are then
counted from amount changes only, which undercounts, and the run says so instead
of quietly reporting a lower bound as a number.

### What the wallet hop costs on top of usage

Point **both** probes at the same target and the run also reports
`current usage → wallet caught up` per event. Both legs are measured from the
same send time on the same clock, so their difference is exactly the gap between
the two observations — no third clock, no second send time. It is clamped at
zero: both are midpoint estimates inside their own poll bracket, so a wallet
reading that landed inside the usage sample's uncertainty reads as "no
measurable gap" rather than as negative time.

If the two probes cover different traffic the split is *not* reported at all —
the two distributions describe different events, and only their percentiles are
comparable. That is detected from the selection, not assumed.

Measured on a local dev stack (which is slow, so read the ratio and not the
absolute numbers): exact mode, usage p50 1.50 s → wallet p50 1.66 s, so the whole
trigger → consumer → bucket-wait → refresh chain added a p50 of **140 ms** on top
of usage being fresh.

### Known limits, surfaced rather than hidden

- **A dead read path does not pace the probe stream.** If the preflight canary
  proves `current_usage` is cache-served, the serial probe loop no longer waits
  on it — otherwise it sends one event and blocks for the whole probe timeout,
  starving the *other* read path. Found exactly that way: a local API whose
  usage was cache-served produced one wallet sample instead of a run's worth.
- **The wallets index serves the full wallet payload**, so its RTT can rival
  `current_usage` (2.5 s p50 on a loaded dev API). Pipelining is what keeps the
  resolution independent of it; the run shows polls/second, RTT and the measured
  uncertainty side by side. The reading itself is a stored column, so polling it
  never triggers the refresh being timed.
- **A pending refresh cannot be mistaken for the calibration event**: the canary
  waits for the balance to stop moving before it sends, then adopts the
  post-canary reading as the baseline.
- **Refresh mode has not been exercised against a real non-standard charge** —
  no such charge existed on the instance it was validated against. Its
  attribution path is the one exact mode exercises; only the label and the bound
  differ.

## Two ways in: the API, or straight to Redpanda

The API path is what a customer's integration exercises, and every latency it
produces includes Lago's ingest cost. That is the right measurement — right up to
the point where **Lago's round trip, not the pipeline, is what the run is
measuring**. Against a remote API answering in ~150 ms, 128 outstanding requests
cap out near 800 events/s however high the target rate is set.

The **Redpanda transport** (Run tab → *transport*) writes the event to the raw
events topic itself, exactly as the API would have, and takes the API out of the
send path entirely. Measured against the local dev broker:

| | events/s |
|---|---|
| POST /events, 128 in flight, remote API | ~800 |
| direct produce, 1 event per request | 37 900 |
| direct produce, 500 per request | **218 800** |
| direct produce, 2 000 per request | 159 900 |

So the sender stops being the limit and the pipeline can be pushed to where it
actually bends. A local run confirmed it end to end: 50 000 events at a sustained
**25 000/s** with zero errors, all 50 000 resolved through both RisingWave
stages — at which point `events_enriched` visibility had risen from 632 ms
(5 000/s) to 5.6 s, which is the pipeline being measured rather than the sender.

### The message is the API's message

Direct produce is only worth anything if the pipeline cannot tell the difference,
so the payload is a faithful copy of what `Events::KafkaProducerService` writes:
`timestamp` as a JSON **string** of float seconds (RisingWave declares that
column VARCHAR), `ingested_at` as ISO-8601 with milliseconds and **no trailing
Z**, `precise_total_amount_cents` defaulting to `"0.0"`, `source: http_ruby`
(both consumers read it as "the Ruby API already evaluated custom expressions" —
anything else makes the Go processor re-evaluate them), `source_metadata.api_post_processed`
read from the organization's events store rather than guessed, and the key
`<organization_id>-<external_subscription_id>`.

Verified rather than asserted: one event through the API and one produced
directly, in the same second, enriched into rows **identical on every column but
the transaction id** — including the charge, filter and value resolved by stage
1+2.

The organization UUID is read from `GET /api/v1/organizations` at preflight,
because it is the key the whole pipeline joins subscriptions, charges and filters
on; a wrong one produces valid JSON that enriches into nothing. It can be
overridden in Setup.

### What direct produce cannot reproduce

The API does one thing Kafka cannot: for an organization whose events store is
**Postgres**, `Events::CreateService` also writes the `events` row and runs
`PostProcessJob`. A direct produce does neither. The RisingWave and ClickHouse
stages are unaffected (they only ever see the topic), but any `current_usage`
read **not** served by the realtime 15-minute buckets has nothing to read.
Preflight names which case the organization is in, and the freshness canary still
decides whether the usage and wallet numbers mean anything — so this shows up as
a stated limitation before the run, never as a mysteriously flat usage curve
after it.

Two segments also change meaning, and the dashboard relabels them from the
server's own catalog rather than the UI guessing:

- **API response** becomes **Produce ack** — the broker ack, not an HTTP round
  trip. With `acks=0` it is only the local write and cannot report a rejection.
- **Lago ingest → Redpanda append** becomes **this app's ingest stamp → Redpanda
  append**: `ingested_at` is now written by the load test, so the leg contains no
  Lago cost and its clock offset is this app's.

Setup → *Direct produce to Redpanda* holds the brokers (from outside Docker that
is the **external** listener, `localhost:19092` in the dev stack, not
`redpanda:9092`), the topic, acks, compression, TLS and SASL for a Cloud broker.
Auto-creation is deliberately **off**: a mistyped topic fails preflight instead
of producing happily into a topic no consumer reads. `events per produce` is
capped at 2 000 because the broker limits a request by **bytes** (1 MB by
default), not by count — and a batch that exceeds it says exactly that.

## Reaching the target rate

The rate a sender actually achieves is **requests in flight divided by round
trip**, and nothing else. Against a remote Lago answering a single-event POST in
~150 ms under load, 128 outstanding requests cap out near 800 events/s however
high the target rate is set — the run then reports a flat line well below what
was asked for, which is a property of the sender, not of the pipeline.

Two knobs on the Run tab decide whether the target is reachable:

- **transport** — the API, or a direct produce (see above). The read paths
  (`current_usage`, `/wallets`) always go through the API whichever is chosen, so
  a direct-produce run measures the same read latencies against a send path that
  is no longer the bottleneck.
- **events per POST** — 1 is one request per event (`POST /events`), which is
  what a per-event integration sends. Above 1 the bulk stream uses
  `POST /events/batch` (Lago's cap is 100), so 5 000 events/s becomes 50
  requests/s instead of 5 000. The events reach exactly the same Kafka topic by
  the same code path; only the number of HTTP requests carrying them changes.
  Every event on one request shares its send timestamp, which is what a batching
  integration submits, so downstream latency is still measured from the moment
  the events were handed to the API.
- **requests in flight** — `0` sizes it from the target rate and the round trip
  the run is actually measuring (`rate ÷ batch × RTT`, 1.5× headroom, capped at
  1024). Pin it to a number to hold concurrency fixed while comparing runs.

Requests go through one tuned HTTP pool (Setup → *HTTP to Lago*). HTTP/2 is
offered by default: when the API accepts it, hundreds of concurrent requests
multiplex over a handful of sockets instead of one TLS connection each. A Lago
that only speaks HTTP/1.1 falls back silently, and *connections* then becomes
the real in-flight ceiling.

Raising the send rate raises what the read path costs too: the usage and wallet
pollers hit the same API, so at high rates a large share of the requests Lago is
serving are the measurement's own. Batching the send path is what keeps that
share from competing with the load being generated.

## Running at 100 000 events/s

Past a few thousand events/s the generator's own bookkeeping, not the send path,
is what breaks first. Everything a run retains is now bounded by a constant
rather than by how many events it sent, so the heap is flat whatever the rate:

| what | before | now |
|---|---|---|
| per-event record | one per event, kept for the whole run | 1-in-N, so a run of any size keeps ~200 000 (`retention.trackEvery`) |
| latency samples | first 200 000 per segment, rest discarded | reservoir of 200 000 per segment, so the late minutes are represented too |
| probe backlog | every probe enrolled on six stages, drained 1 000/s | probe cadence floored at 50/s, and 2 000 per stage max |
| usage / wallet attribution | one entry per event forever, rescanned from zero on every poll | attributed entries dropped, scan starts at the watermark, outstanding capped |
| per-second throughput buckets | one per second forever | last 900 |

None of this changes what is measured. Every event is still counted, and still
moves the usage and wallet predictions the attribution is checked against — only
the *per-event record*, which exists to turn stamps into latency samples, is
sampled, and no segment retains more than 200 000 samples anyway. `summary.json`
carries a `retention` block saying exactly what the run kept, including its peak
heap, so a reader knows which numbers are a sample and which are the population.

A 20 M-event soak of the record path holds a flat 186 MB. If a run does approach
the heap ceiling it now says so in the log while it can still be read, instead of
dying on `Ineffective mark-compacts near heap limit`; raise it with
`NODE_OPTIONS=--max-old-space-size=8192` (the npm scripts already do).

**Is the generator the ceiling?** Measure it directly, with no pipeline in the
way — same message bytes, same producer settings, throwaway topic:

```
npm run bench --workspace server -- 5000000 2000 32 1
# 5,000,000 events in 26.12s = 191,410 events/s, peak heap 98MB
rpk topic delete lt-bench-scratch
```

On this dev box that is ~1.9× the 100 k/s target, so a run that flatlines below
it is reporting the pipeline, not the sender. Use the direct-produce transport
(`kafka`) with **events per produce** at 1 000–2 000: the API transport cannot
reach these rates, because Lago's own ingest is then what is being measured.

## Guards

Rate, total, optional ramp, and `stop above N% errors` (windowed over 10 s; 0
disables it). There is no size ceiling — a run is as large as `total` says.
A run also stops early if no probe has made progress for 15 s
rather than waiting out the full probe timeout, and it says which stages it gave
up on.

## Output

Live via SSE, and persisted per run under `runs/<id>/`:

| file | contents |
|---|---|
| `preflight.json` | what was reachable, the clock offsets, the resolved table names |
| `summary.json` | spec, counters, percentiles, histograms, throughput, errors, logs |
| `events.jsonl` | one line per *tracked* event (every probe, plus 1 bulk event in `retention.trackEvery`): send time, API time, per-stage first-seen, every stamp, and the usage / wallet leg where one was attributed |

`summary.json` is exactly what the dashboard renders, so History replays a past
run through the same view as a live one.

## Layout

```
server/   Fastify. Lago + RisingWave (pgwire) + ClickHouse (HTTPS) + Redpanda
          (kafkajs) clients, discovery, run orchestration, cohort pollers, stamp
          sweeps, SSE.
  src/clients/redpanda.ts  the direct producer, and the one place the API's own
                   Kafka payload is reproduced — every field that has to match
                   is documented against the Ruby it mirrors
  src/clients/events.ts    the two transports behind one signature, so
                   everything downstream of the send is transport-blind
  src/types.ts     the segment catalog — the UI renders itself from this, so what
                   the dashboard claims and what the server computes cannot drift
  src/run/crossing.ts  the shared attribution machinery (bracketing, coalescing
                   counts, freshness verdict). Both the usage and the wallet
                   measurement run on it, so neither can drift from the other
  src/run/stats.ts     bounded percentiles: a reservoir per segment and one sort
                   per second, so reporting cannot starve the sender
  src/bench/produce.ts what the SENDER can do with no pipeline in the way, so a
                   flat line can be blamed on the right side
  src/__tests__/   the invariants worth pinning: that the fast produce path is
                   byte-identical to the general one, and that nothing the runner
                   retains grows with the number of events sent
web/      React + Vite. Charts are hand-rolled SVG against theme tokens.
```

Chart colors come from a palette validated for colorblind separation and contrast
in both light and dark mode: an ordinal single-hue ramp for P50→P95→P99 (ordered
magnitude, not three unrelated categories), the first three categorical slots for
the hop waterfall, and reserved status colors that are never reused as series
colors.
