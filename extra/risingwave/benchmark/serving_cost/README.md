# ClickHouse serving cost: `usage_buckets_15m` vs `events_enriched`

Run 2026-08-25 on the dev stack (32 cores, ClickHouse 26.2.19). Answers the
question "does serving current usage from 15-minute buckets cost a lot of
ClickHouse CPU compared to the old `events_enriched` queries?" — and, as a side
effect, found the missing `organization_id` key prefix fixed the same day
(ROADMAP §0b).

All figures are the median of 5 runs, CPU read from
`system.query_log.ProfileEvents['OSCPUVirtualTimeMicroseconds']`. Dev is a
shared box: treat absolute CPU as indicative and the ratios as the result.

## Dataset

Synthetic, deliberately prod-shaped — dev's real data hides every effect here,
because one organization owns every row.

| table | rows | shape |
|---|---|---|
| `bench.buckets_mo` | 172.8M (2.39 GiB) | 500 orgs × 40 subs × 3 charges × 2,880 buckets — one full month, UUID-shaped org/sub/charge ids |
| `bench.events` | 30.2M (1.45 GiB) | `events_enriched` shape: 200 subs at 86.4k events/month, 5 subs at 2.59M events/month |

`bench.buckets` is created empty by `01_schema.sql` and used only as a schema
template (`CREATE TABLE ... AS bench.buckets`) by the part-count and
partitioning tests.

Compressed bucket storage is ~14 bytes/row, so a month of 20k subscriptions ×
3 charges at full 15-minute fill is ~2.3 GiB.

## Read cost — one subscription+charge, 30-day window

| path | CPU | rows read | memory |
|---|---|---|---|
| **buckets `FINAL`, org prefix** | **20.6 ms** | 74k | 33 MiB |
| `events_enriched` dedup CTE, sub at 86k events/mo | 85.9 ms | 180k | 49 MiB |
| `events_enriched` dedup CTE, sub at 2.6M events/mo | 10,091 ms | 5.2M | 1.05 GiB |

4× cheaper for a quiet subscription, 490× for a busy one. The important
property is not the ratio but its shape: a bucket read is bounded at 2,880 rows
per charge per month **no matter the event rate**, while the `latest_enriched`
GROUP BY + `INNER ANY JOIN` is linear in events. The gap widens with every
event a customer sends.

`events_enriched_expanded` (the feature-flagged `ClickhouseEnrichedStore`) is
worse still — it fans out per charge × filter, 240M rows against 738k for
`events_enriched` on the same dev data.

## The `organization_id` key prefix

`ORDER BY (organization_id, subscription_id, charge_id, charge_filter_id,
grouped_by, bucket)`. A query that omits the leading column cannot use the
primary key at all:

| query | without org | with org |
|---|---|---|
| wallet watermark poll (`RealtimeRefreshService#wait_for_buckets`) | 100.6 ms / 3.65M rows | **1.9 ms / 8.2k rows** |
| per-subscription totals (`ParityCheckService`) | 3,792 ms / 10M rows | **~20 ms / 74k rows** |

The wallet poll runs every `BUCKET_WAIT_INTERVAL = 0.1s` for up to 5s per
wallet refresh. At 200 refreshes/s averaging 3 polls each that is ~60 cores of
ClickHouse answering "did the bucket land yet", against ~1 core with the
prefix. Both fixed 2026-08-25.

## Write cost

At `barrier_interval_ms = 250` + `commit_checkpoint_interval = 1` (4 commits/s
into ClickHouse), 120s of sustained writes:

| commit shape | inserts | merges | merge CPU | active parts |
|---|---|---|---|---|
| 4/s × 25 rows | 475 | 116 | 0.23 s | 3 |
| 1/s × 400 rows | 120 | 29 | 0.08 s | 2 |

The 4-inserts/second cadence is not a problem: merge CPU is a fraction of a
percent of one core, and ClickHouse holds the active part count down on its
own. ReplacingMergeTree collapses aggressively (11,875 rows written → 75 live).

## `FINAL` scales with part count, not table size

Measured with merges stopped, same point read, growing the number of active
parts overlapping the key:

| active parts | CPU | rows read |
|---|---|---|
| 15 | 28.1 ms | 115k |
| 24 | 57.3 ms | 192k |
| 33 | 151 ms | 385k |
| 42 | 191.7 ms | 463k |
| 51 | 236.3 ms | 540k |

~4.6 ms of CPU per part. Merges kept up easily in the write test above, so this
is the metric to alert on in prod shadow — active part count on
`usage_buckets_15m`, not row count.

## Monthly partitioning

`PARTITION BY toYYYYMM(bucket)`, added 2026-08-25. Measured on 6 months of
history (83M rows) with the parity sweep — the one bucket query that has no
organization to scope by:

| | rows read | CPU |
|---|---|---|
| flat | 8.98M | 3,141 ms |
| partitioned | 3.72M | 1,079 ms |

2.9× at six months, and widening: the partitioned cost stays flat as history
accumulates while the flat one grows linearly. Partitioning also keeps merges
inside one month and turns retention into a `DROP PARTITION` rather than a TTL
mutation — which matters because ClickHouse keeps forever-history here while
RisingWave holds only ~32 days.

A partition key cannot be `ALTER`ed in. Changing it means CREATE new +
`INSERT SELECT ... FINAL` + `EXCHANGE TABLES` + DROP. The RisingWave sink
survives that untouched: it inserts by table name over HTTP and `EXCHANGE` is
atomic (verified — an event produced to `events-raw` right after the swap
landed in ClickHouse in 234 ms).

## Reproduce

Generation takes ~30 minutes and leaves ~9 GiB in the `bench` database; drop it
when done.

```sh
cd extra/risingwave/benchmark/serving_cost
docker exec -i lago_clickhouse_dev clickhouse-client --user default \
  --password default --multiquery < 01_schema.sql

./gen_multiorg.sh 500 40 25        # 172.8M bucket rows over 500 orgs
./gen_events.sh 0 200 86400 10     # medium-volume subscriptions
./gen_events.sh 1000 1005 2592000 1  # heavy-volume subscriptions

./run_mo.sh          # read cost, with and without the org prefix
./write_test.sh tiny 4 25 120      # write/merge cost at the prod commit cadence
./write_test.sh big 1 400 120      # ...against a 1/s cadence
./parts_test2.sh     # FINAL cost vs active part count (stops merges)
./part_bench.sh      # partitioned vs flat over 6 months of history

docker exec lago_clickhouse_dev clickhouse-client --user default \
  --password default -q "DROP DATABASE bench"
```

`write_test.sh` and `parts_test2.sh` create their own tables. `parts_test2.sh`
issues `SYSTEM STOP MERGES` on its table and restarts merges at the end — if it
is interrupted, run `SYSTEM START MERGES bench.frag` by hand before dropping.
