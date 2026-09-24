# matching_filter v3: charge filters by lookup, not by scan

A shadow of the stage-1 enrichment job (`events_expanded_load`,
`../sql/04_enrichment.sql`) that finds an event's charge filter with point
lookups instead of passing the charge's filter list to a UDF. It runs next to
the production pipeline on the same RisingWave instance, reads the same
`events_enriched`, and writes `events_expanded_v3`. Nothing consumes that
table: it exists to be diffed against `events_expanded` and measured on real
traffic. It is built on the production `flat_filters_agg_mv` and does not
depend on `../slim_filters`.

## Problem

For every (event, charge), production passes `flat_filters_agg.filters_agg`
(the charge's whole candidate array) to the `matching_filter` WASM UDF. Some
production charges have ~3,000 filters, so every event on them moves hundreds
of KB into WASM, and stage 1 backs up.

## Idea

Turn the comparison around. A filter such as
`{model: [gpt4, gpt4o], token_type: [input]}` matches an event exactly when the
event's `(model, token_type)` values are one of the filter's combinations. So:

- **Dimension side (CDC churn only):** each filter is expanded into one
  *lookup key* per combination of its allowed values, stored in
  `filter_lookup (charge_id, lookup_key) -> rank`. A charge's *shapes* are the
  distinct sorted key sets of its filters (`[model, token_type]`).
- **Event side:** for each of the charge's shapes, build the event's key from
  its properties and do one point lookup. The best rank among the hits wins.

The cost per event depends on the number of shapes (p99 = 1 in production),
not on the number of filters. The 3,000-filter charges have one or a few
shapes, so they cost one or a few lookups.

## Matching rules (unchanged)

Same result as production `matching_filter`, checked by the parity suite:

- A filter matches when every key is present and non-null on the event and
  the property's JSON text (`json_value_text`, the production rule) is an
  allowed value. The key is built from that same text, so numbers and
  booleans compare the same way as in production.
- More keys wins, then the first filter in `filters_agg` order:
  `rank = key_count * 1e9 + (999999999 - position)`. Filters with the same key
  (same shape, overlapping values) collapse to the best rank.
- No hit means the default bucket: no filter identity, `pricing_group_keys`
  from element 0 (ToDefaultFilter).
- Filters that can never match produce no lookup row: an empty map, a
  valueless filter (`{"": null}`), and value lists with no string value.

## Fallback

A charge goes to the production path (`matching_filter` on the production
`flat_filters_agg`) when it has **more than 8 shapes** or a filter expands to
**more than 256 combinations**. `filter_lookup_charges.fallback` says which
path a charge takes. The fallback join uses a key that is NULL for every other
charge, so lookup charges never read `filters_agg`. Production numbers from
2026-09-24: 14 charges have more than 8 shapes (17 filters each), and the
largest expansion is 31 combinations for one filter.

## Objects

Dimension side (`sql/02_lookup.sql`):

| Table | Rows | Holds |
|---|---|---|
| `filter_lookup_charges` | one per charge | shapes (or `fallback`), charge attributes, default `pricing_group_keys` |
| `filter_lookup` | one per (charge, lookup key) | best rank for that key |
| `filter_lookup_positions` | one per (charge, filter position) | winner details (`charge_filter_id`, `filters`, ...) |

Event side (`sql/03_enrichment_v3.sql`): `filter_lookup_event_keys(shapes,
properties)` returns one key per shape, then 8 left temporal joins on
`filter_lookup` (one per shape slot), `GREATEST(rank)`, rank -> position, and a
point lookup in `filter_lookup_positions`. Everything is stateless (temporal
joins on an append-only LHS keep no state).

UDFs (`udf/src/`, generated into `sql/01_functions.sql`):

| UDF | Runs | Input |
|---|---|---|
| `filter_lookup_plan(filters_agg)` | per charge, on CDC | whole `filters_agg` |
| `filter_lookup_expand(filters)` | per filter, on CDC | one filter's map |
| `filter_lookup_event_keys(shapes, properties)` | per (event, charge) | shape key names + properties |

Lookup key format, `(str(key) str(value))*` over the keys in byte order with
`str(x) = <octet_len> ':' <bytes>`: no escaping, and no two combinations share
a key.

## Run it

Needs the production pipeline applied (`../setup.sh`).

```bash
cd extra/risingwave/matching_filter_v3/udf && cargo test && ./gen_sql.sh

# The shadow only processes events with kafka_timestamp >= SHADOW_SINCE
# (default: now). Set it in the past to diff recent history right away.
SHADOW_SINCE='2026-09-25T08:00:00Z' ./extra/risingwave/matching_filter_v3/setup.sh

psql -h localhost -p 4566 -d dev -U root -f extra/risingwave/matching_filter_v3/stats.sql
./extra/risingwave/matching_filter_v3/parity.sh 30 20   # settle seconds, sample size

./extra/risingwave/matching_filter_v3/teardown.sh
```

`stats.sql` shows how charges are routed (fallback count, shapes per charge,
lookup size) and checks v3's decision against `matching_filter` on the latest
100k events without needing the shadow.

## Validated locally (2026-09-25, RisingWave 3.0.2)

On a scratch schema with stand-ins for `flat_filters_agg_mv`,
`flat_filters_agg`, `subscriptions_agg` and `events_enriched`:

- `cargo test`: 20 tests, every production `matching_filter` case, encoding
  edge cases, the fallback rules and 50k randomized cases against the
  production UDF.
- The three UDFs compile under the embedded Rust toolchain.
- Row-level parity with the production expression, 0 mismatches:
  - 232 rows (events inserted before and after the sink was created, covering
    a 3,001-filter charge, several shapes with equal key counts, parent/child
    filters, a 9-shape fallback charge, a filterless charge, valueless and
    numeric filters, JSON null, a missing subscription);
  - 93 rows after CDC updates (a filter removed, a 3-key filter added, a
    charge moving from fallback to lookup and another from lookup to
    fallback, a charge deleted).
- Throughput on the 3,001-filter charge, same instance, one job at a time:
  production stage 1 took **63 s for 20k events** (~317 ev/s). v3 took
  **2.7 s for 200k events** (~74k ev/s, insert included). The two outputs for
  the 20k events agreed on every row.

Not yet done: a run on real data, and a load test on staging.

## Known limits / gotchas

- `NOTICE: The plan is too deep` on the shadow sink (8 chained temporal joins).
  It is only a notice; the job runs.
- `FLV3_SHAPE_SLOTS` (`udf/src/flv3_common.rs`) must equal the number of
  lookup joins in `03_enrichment_v3.sql`.
- During a filter change, `filter_lookup_charges`, `filter_lookup` and
  `filter_lookup_positions` are updated by three sinks. An event resolved in
  between could read new shapes against old keys (or the reverse). Production
  reads one row and cannot hit this. `parity.sh` shows it as a mismatch on
  events around the change.
- Updating a charge re-expands all its filters (~3,000 lookup rows and 3,000
  position rows for the widest charges). This is CDC-only work, but a bulk
  edit that touches every filter of such a charge one by one costs about
  filters² row changes.
- Same sink-into-table backfill note as `../slim_filters`: the backfill is cut
  by the constant `SHADOW_SINCE` filter.
