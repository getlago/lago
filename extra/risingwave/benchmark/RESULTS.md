# Ingestion → current-usage latency: ClickHouse path vs RisingWave path

Run 2026-08-07 on the dev stack (zero background load). 3 cases × 3
subscriptions × 2 rounds × 2 paths = 36 measurements, interleaved, no
timeouts. Method: produce one event to `events-raw` (both pipelines consume
it), poll the real Rails aggregation layer (`AggregationFactory` →
`aggregate`, i.e. what `Fees::ChargeService` executes for current usage)
every 200 ms until the value reflects the event. Read path toggled per
measurement via `LAGO_REALTIME_USAGE_ENABLED`.

| Case | Path (aggregator actually used) | avg | min | max |
|---|---|---|---|---|
| count, no filters | ClickHouse (`Aggregations::CountService`) | 866 ms | 627 ms | 1037 ms |
| count, no filters | **RisingWave** (`Realtime::CountService`) | **377 ms** | 209 ms | 1016 ms |
| sum, charge filter (tier=gold) | ClickHouse (`Aggregations::SumService`) | 860 ms | 222 ms | 1117 ms |
| sum, charge filter (tier=gold) | **RisingWave** (`Realtime::SumService`) | **647 ms** | **8 ms** | 1018 ms |
| sum, pricing_group_keys (region) | ClickHouse (`Aggregations::SumService`) | 924 ms | 225 ms | 1085 ms |
| sum, pricing_group_keys (region) | RisingWave → fallback to ClickHouse *(before grouped read)* | 1065 ms | 1059 ms | 1074 ms |
| sum, pricing_group_keys (region) | **RisingWave** (`Realtime::SumService`, grouped read) | **276 ms** | 208 ms | 411 ms |

## Reading the numbers

- **RisingWave wins on eligible cases** (count ~2.3× faster on average), and
  its 8 ms minimum shows the floor: when the sink commit lands before the
  first poll, freshness is essentially instant. Both paths show a ~1 s
  ceiling in dev — RisingWave's barrier/sink-commit cadence
  (`barrier_interval_ms = 1000`, tunable) vs ClickHouse's Kafka flush
  cadence. Poll resolution adds ±200 ms of noise to every figure.
- **The grouped case initially fell back** (matching the ClickHouse rows —
  fallback is free). After implementing the grouped projection read
  (`compute_grouped_by_aggregation` overrides, one result per `grouped_by`
  row), the rerun shows it realtime: avg 276 ms vs 785 ms for the ClickHouse
  path in the same run. Fallback still applies when group keys disagree with
  the charge's current `pricing_group_keys` (stale attribution after edits).
- **Dev flatters the ClickHouse path.** Zero load means idle consumers, tiny
  tables, and instant flushes; this is its best case. Under production
  volume the ClickHouse path degrades with consumer lag and per-request
  aggregation query cost (the same queries behind the wallet-refresh CPU
  problem), while the RisingWave read is a single-row indexed lookup whose
  freshness is bounded by the pipeline (~65–625 ms emit latency measured),
  independent of data volume.
- Freshness is only half the comparison: every ClickHouse-path poll runs a
  full aggregation query; the RisingWave-path read is O(1) regardless of
  event count. The per-request cost gap widens with scale even where the
  freshness gap doesn't.

## Reproduce

```sh
mkdir -p api/tmp/rw_benchmark && cp extra/risingwave/benchmark/*.rb api/tmp/rw_benchmark/
docker exec lago_api_dev bin/rails runner tmp/rw_benchmark/seed.rb
docker restart lago_events-processor   # refresh its dimension cache snapshot
docker exec lago_api_dev bin/rails runner tmp/rw_benchmark/benchmark.rb
# ENV knobs: ROUNDS (2), POLL_MS (200), TIMEOUT_S (90)
```
