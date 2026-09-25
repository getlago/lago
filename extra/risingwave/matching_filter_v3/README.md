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

## Worked example

A charge `ch1` with three filters, in `filters_agg` order (sorted by
`charge_filter_id`):

| Position | Filter | updated_at |
|---|---|---|
| 0 | `{model: [gpt4, gpt4o], token_type: [input]}` | 2026-09-01 |
| 1 | `{model: [gpt4], token_type: [output]}` | 2026-09-03 |
| 2 | `{model: [gpt4]}` | 2026-09-02 |

**1. When the charge changes (CDC).** `filter_lookup_plan` finds two shapes,
`[model, token_type]` and `[model]`, and stores them in
`filter_lookup_charges`. `filter_lookup_expand` turns each filter into its
value combinations, written into `filter_lookup` with their rank (more keys
first, then the least recently updated; see "Matching rules"):

| lookup_key (shown readable) | From position | Rank |
|---|---|---|
| `model=gpt4, token_type=input` | 0 | 2 keys, 1st by updated_at |
| `model=gpt4o, token_type=input` | 0 | 2 keys, 1st by updated_at |
| `model=gpt4, token_type=output` | 1 | 2 keys, 3rd by updated_at |
| `model=gpt4` | 2 | 1 key, 2nd by updated_at |

The real keys are length-prefixed (`5:model4:gpt410:token_type5:input`), so
a value containing `,` or `=` can't produce another combination's key.

**2. Per event.** Event `{model: gpt4, token_type: input, region: eu}` on
`ch1`:

- `filter_lookup_event_keys` builds one key per shape:
  `model=gpt4, token_type=input` and `model=gpt4`. `region` is ignored
  because no shape uses it.
- Slot 1 finds position 0 (2 keys); slot 2 finds position 2 (1 key); slots 3-8
  are NULL and find nothing.
- `GREATEST(rank)` picks position 0: more keys wins, the same answer the
  API's `EventMatchingService` gives.
- One more lookup in `filter_lookup_positions` on `(ch1, 0)` returns
  `charge_filter_id`, `filters` and `pricing_group_keys`.

Other events on the same charge:

| Event | Hits | Result |
|---|---|---|
| `{model: gpt4, token_type: cached}` | `model=gpt4` only | position 2 |
| `{model: gpt4o}` | none (shape 1 needs `token_type`, shape 2 has no `gpt4o`) | default bucket |
| `{model: null, token_type: input}` | none (null reads as `""`, which no filter allows) | default bucket |

Adding a 3,000th filter changes nothing on the event side: it is one more row
in `filter_lookup`, still found by the same one or two lookups.

## Why this approach

- **Production (`matching_filter` on `filters_agg`)**: correct, but the whole
  array is serialized into WASM on every event. ~3.7 ms of the ~3.85 ms per
  call on a 2,500-filter charge is just passing the argument
  (`../slim_filters/README.md`).
- **Slim filters (`../slim_filters`)**: a compact payload makes the call ~10x
  cheaper, but it is still a scan of every filter per event, so the cost
  grows with the charge.
- **Anchor bucketing** (split filters by the value of one key every filter
  uses): shrinks the scan, but it only helps when such a key exists and the
  buckets are small, and it keeps the UDF scan.
- **Lookups (this folder)**: exact equality on precomputed keys. The work
  moves to CDC time, where it runs once per filter change instead of once
  per event, and the event path no longer depends on how many filters a
  charge has. The fallback scans the list for the rare charges with too many
  shapes, with the same rules, so both paths give the same answer.

## Matching rules (the API's)

v3 picks the filter the API picks per event, in
`Events::BillingPeriodFilters::EventMatchingService`
(`api/app/services/events/billing_period_filters/event_matching_service.rb`):

```ruby
matching = charge.filters.select { |f| f.to_h.all? { |k, v| props.key?(k) && props[k].to_s.in?(v) } }
matching.max_by { |f| f.to_h.keys.size }   # charge.filters: default_scope order(updated_at: :asc)
```

The parity suite checks every rule against a port of that Ruby:

- A filter matches when every key is on the event and the property's text is
  an allowed value. The text is the production `json_value_text` rule, except
  that a JSON null reads as `""` (Ruby's `nil.to_s`).
- More keys wins. On a tie, the **least recently updated** filter wins,
  because `max_by` keeps the first maximum and `ChargeFilter`'s default scope
  orders by `updated_at` ASC. Postgres leaves equal `updated_at` in no defined
  order, so v3 breaks those ties on `charge_filter_id`.
- A charge filter without values (`{"": null}` in `flat_filters`) has an
  empty `to_h`, so it matches every event with 0 keys: it wins over the
  default bucket, and any keyed match beats it. Its rank is stored on the
  charge (`empty_filter_rank`) and joins the lookup hits in `GREATEST`.
- One BIGINT per lookup row encodes all of it:
  `rank = key_count * 1e12 + (999999 - api_order) * 1e6 + position`, where
  `api_order` is the filter's index in the (`updated_at`, id) order and
  `position` its index in `filters_agg`, read back with `rank % 1e6`.
  Filters with the same key (same shape, overlapping values) collapse to the
  best rank.
- No hit means the default bucket: no filter identity, `pricing_group_keys`
  from element 0 (production's ToDefaultFilter).
- Value lists with no string value never match and produce no lookup row.

### Differences from production RisingWave

Production `matching_filter` (the Go processor's rules) differs on exactly
three cases, so a diff against `events_expanded` shows these on purpose:

| Case | Production | v3 (API) |
|---|---|---|
| Two matching filters with the same key count | first by `charge_filter_id` | least recently updated |
| Charge filter without values | never matches | matches every event with 0 keys |
| JSON-null property | absent | reads as `""` |

`stats.sql` counts them as `changed_vs_production`.

## Fallback

A charge is resolved by `filter_lookup_fallback`, a full scan of the
production `flat_filters_agg` with the same rules, when it has **more than 8
shapes** or a filter expands to **more than 256 combinations**.
`filter_lookup_charges.fallback` says which path a charge takes. The fallback
returns a position too, so both paths read the winner from
`filter_lookup_positions`. Its join uses a key that is NULL for every other
charge, so lookup charges never read `filters_agg`. Production numbers from
2026-09-24: 14 charges have more than 8 shapes (17 filters each), and the
largest expansion is 31 combinations for one filter.

## Objects

Dimension side (`sql/02_lookup.sql`):

| Table | Rows | Holds |
|---|---|---|
| `filter_lookup_charges` | one per charge | shapes (or `fallback`), `empty_filter_rank`, charge attributes, default `pricing_group_keys` |
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
| `filter_lookup_expand(filters_agg)` | per charge, on CDC | whole `filters_agg` (a rank depends on the charge's `updated_at` order) |
| `filter_lookup_event_keys(shapes, properties)` | per (event, charge) | shape key names + properties |
| `filter_lookup_fallback(filters_agg, properties)` | per (event, charge), fallback charges only | whole `filters_agg` |

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
lookup size), and on the latest 100k events, without needing the shadow,
checks that the lookup path agrees with `filter_lookup_fallback`
(`lookup_vs_scan_mismatches` must be 0) and counts the events whose filter
changes compared with production (`changed_vs_production`).

## Validated locally (RisingWave 3.0.2)

On a scratch schema with stand-ins for `flat_filters_agg_mv`,
`flat_filters_agg`, `subscriptions_agg` and `events_enriched`.

With the API's rules (current code):

- `cargo test`: 23 tests against a port of the API's `EventMatchingService`,
  covering ties on `updated_at` (including fractional seconds and equal
  timestamps), filters without values, JSON null, the encoding, the fallback
  rules, and 50k randomized cases. Both the lookup path and
  `filter_lookup_fallback` are checked against the port.
- The four UDFs compile under the embedded Rust toolchain.
- 525 shadow rows (events before and after the sink was created, on 6
  charges: the 3,001-filter one, several shapes, a 9-shape fallback charge
  with a filter without values, a filterless charge, ties on `updated_at`, a
  `""` value), 0 mismatches against `filter_lookup_fallback`. Against
  production `matching_filter`, the only differences were the three cases in
  the table above.

With the earlier production rules (before switching to the API's rules):

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
  the 20k events agreed on every row. The event path changed little since (one
  more argument to `GREATEST`); throughput was not measured again.

Not yet done with the API's rules: a run on real data, and a load test on
staging.

## Known limits / gotchas

- `NOTICE: The plan is too deep` on the shadow sink (8 chained temporal joins).
  It is only a notice; the job runs.
- The shadow sink uses `BROADCAST LEFT JOIN`, which RisingWave 3.0.2 does not
  parse. The local runs above removed `BROADCAST` from a copy of the file.
- The tie-break reads `charge_filter_updated_at` as text. It sorts correctly
  because `02_flat_filters.sql` renders it as `YYYY-MM-DD HH:MM:SS[.ffffff]`;
  a format change there would need `flv3_api_order` to follow.
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
