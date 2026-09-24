# Slim filters: shadow stage 1 with a cheap filter-matching path

A shadow of the stage-1 enrichment job (`events_expanded_load`,
`../sql/04_enrichment.sql`) that resolves charge filters without moving the
charge's whole filter array into a UDF per event. It runs next to the
production pipeline on the same RisingWave instance, reads the same
`events_enriched`, and writes `events_expanded_slim`. Nothing consumes that
table: it exists to be diffed against `events_expanded` and measured on real
traffic.

## Problem

For every (event, charge), production passes `flat_filters_agg.filters_agg`
(the charge's full candidate array) to the `matching_filter` WASM UDF. On a
charge with thousands of filters (the AI-company shape: model × token type),
stage 1 slows to a crawl.

Measured on local RisingWave 3.0.2, synthetic charge with 2502 filters
(556 KB JSONB), 200 calls per query, steady state (`bench/marshalling.sh`):

| UDF call | per call |
|---|---|
| noop, receives `filters_agg` JSONB | ~3.7 ms |
| `matching_filter` (production) | ~3.85 ms |
| noop, receives `match_payload` VARCHAR | ~0.3 ms |
| `match_filter_position` (this folder) | ~0.35–0.43 ms |
| `match_filter_position` + `filters_agg -> position` read back | ~0.92 ms |

About 96% of the production cost is **passing** the JSONB into WASM
(rendering it to text, copying it, `serde_json` building a full tree). The
matching loop itself is noise. Reading the winner back from `filters_agg`
still costs ~0.5 ms, because the 556 KB column travels with every row, so
the shadow stops carrying `filters_agg` on the event path at all.

## Design

Dimension side (`sql/02_payload.sql`, updated on CDC churn only, built on the
production `flat_filters_agg_mv` without touching it):

- `flat_filters_slim`: one row per charge, **without** `filters_agg`. It
  holds `match_payload`, a compact length-prefixed VARCHAR of each filter's
  `{key: [values]}` (130 KB for the 2502-filter charge, 4.3× smaller), and
  `default_pricing_group_keys` (element 0's, which is what ToDefaultFilter
  keeps).
- `charge_filter_positions`: one row per (charge, position in `filters_agg`)
  holding the winner's details. It is exploded with `WITH ORDINALITY` from the
  same array the payload is encoded from, so positions line up by
  construction.

Event side (`sql/03_enrichment_slim.sql`): a copy of production stage 1 with
one change, the filter resolution:

1. `match_filter_position(match_payload, properties)` scans the payload bytes
   in place (no JSON parse, no allocation per filter, a non-matching filter
   is skipped in O(1)) and returns the winner's position, or `-1` for the
   default bucket.
2. A stateless temporal-join point lookup in `charge_filter_positions` on
   that position fetches `charge_filter_id`, `charge_filter_updated_at`,
   `filters` and `pricing_group_keys`.

Matching rules are the production ones: every key present and non-null, the
JSON text of the value in the allowed list, most keys wins, first of equals,
default bucket otherwise. Work per event is still linear in the number of
filters, but as a byte scan roughly 10× cheaper than today. If charges grow
another order of magnitude, the next step is an exact-match index (per key-set
hash lookups, O(#key-sets) per event).

Payload format (`udf/src/match_filter_position.rs`):

```
payload = filter*
filter  = str(body)
body    = <nkeys> ';' ( str(key) values ){nkeys}
values  = <nvalues> ';' str(value){nvalues}  |  'n'   (never matches)
str(x)  = <octet_len> ':' <bytes>
```

Length prefixes mean no escaping: user values may contain any byte.

## Files

| Path | What |
|---|---|
| `udf/src/*.rs` | UDF sources. `cargo test` runs a parity suite against the production `matching_filter` (every existing case, encoding edge cases, 20k randomized cases) |
| `udf/gen_sql.sh` | Generates `sql/01_functions.sql` from the Rust sources |
| `sql/01_functions.sql` | `encode_filter_payload`, `match_filter_position` (generated) |
| `sql/02_payload.sql` | `flat_filters_slim`, `charge_filter_positions` |
| `sql/03_enrichment_slim.sql` | `events_expanded_slim` and its load sink |
| `setup.sh` / `teardown.sh` | Apply / remove the shadow. Only new objects, production untouched |
| `parity.sh` | Row-level diff `events_expanded` vs `events_expanded_slim` |
| `bench/marshalling.sh` | UDF cost breakdown on a real charge (the table above) |

## Run it

Needs the production pipeline applied (`../setup.sh`).

```bash
cd extra/risingwave/udf && cargo test                     # production UDFs
cd ../slim_filters/udf && cargo test && ./gen_sql.sh      # slim UDFs + regenerate SQL

# Shadow only processes events with kafka_timestamp >= SHADOW_SINCE
# (default: now). Set it in the past to diff recent history right away.
SHADOW_SINCE='2026-09-24T08:00:00Z' ./extra/risingwave/slim_filters/setup.sh

./extra/risingwave/slim_filters/parity.sh 30 20   # settle seconds, sample size
./extra/risingwave/slim_filters/bench/marshalling.sh 200            # biggest charge
./extra/risingwave/slim_filters/bench/marshalling.sh 200 <charge_id> '<properties json>'

./extra/risingwave/slim_filters/teardown.sh
```

To compare throughput, pause one of the two stage-1 jobs while load-testing
the other: they share the instance's CPU.

## Validated locally (2026-09-24)

On a scratch schema with stand-ins for the production relations (the local
instance ran an older pipeline):

- Both UDFs compile under RisingWave 3.0.2's embedded Rust toolchain.
- The shadow was applied end to end, with events inserted both before the sink
  (backfill) and after (streaming), plus one older than `SHADOW_SINCE`
  (correctly excluded). The 14 output rows matched the production expressions
  (`matching_filter` + the production projection) on every compared column:
  wide charge last and first filter, default bucket, parent/child
  most-keys-wins, valueless filter, filterless charge, null default
  `pricing_group_keys`, numeric property, `target_wallet_code`.
- `parity.sh` reported `same` on identical tables and flagged a planted
  mismatch and a planted extra row.

Not yet done: a run on real data, and a throughput comparison under load.

## Known limits / gotchas

- A sink-into-table backfills its whole upstream, and `snapshot = 'false'` is
  rejected on a sink with a query ("only support `CREATE SINK FROM MV or
  TABLE`"), so the backfill is cut by the constant `SHADOW_SINCE` filter.
- During a filter change, `flat_filters_slim` and `charge_filter_positions`
  are updated by two sinks. An event resolved in between could read a
  position from the new payload against old position rows (or the reverse).
  Production reads one row and cannot hit this. `parity.sh` would show it as a
  mismatch on events around the change.
- `bench/marshalling.sh`: keep `calls` small. 1000 calls on the 556 KB row
  crashed a local RisingWave standalone (the batch holds calls × row in
  memory).
- RisingWave parses `a IS DISTINCT FROM b OR ...` with the wrong precedence on
  JSONB (`or(jsonb, boolean) does not exist`): parenthesize each comparison.
  Named arguments (`make_interval(secs => ...)`) are not supported either.
