-- GENERATED FILE — DO NOT EDIT BY HAND.
-- Source of truth: extra/risingwave/matching_filter_v3/udf/src/*.rs (cargo
-- test runs a parity suite against a port of the API's
-- ChargeFilters::EventMatchingService);
-- regenerate with extra/risingwave/matching_filter_v3/udf/gen_sql.sh.
--
-- filter_lookup_plan and filter_lookup_expand run on the dimension side (CDC
-- churn only): they turn a charge's filters_agg into its shapes and one
-- ranked lookup key per (filter, value combination). filter_lookup_event_keys
-- runs per (event, charge) on small inputs (the charge's shapes and the event
-- properties) and returns the event's lookup key per shape, so the filter
-- list never crosses the WASM boundary on the event path.
-- filter_lookup_fallback scans the whole list with the same rules, for the
-- rare charges the lookups cannot serve.

CREATE FUNCTION IF NOT EXISTS filter_lookup_plan(filters_agg JSONB) RETURNS JSONB
LANGUAGE rust AS $$
// Dimension side, once per charge on CDC churn: decides how the charge is
// matched per event.
//
// `filters_agg` is one charge's flat_filters_agg array. Returns
//   {"fallback": bool, "shape_count": n, "shapes": [[key, ...], ...],
//    "empty_filter_rank": rank | null}
// where a shape is the sorted key set of a keyed filter (see
// flv3_filter_terms). Shapes are ordered by key count desc, then by keys, so
// the output is canonical; the order does not affect the winner.
//
// empty_filter_rank is the best rank among the charge filters without
// values, which match every event with 0 keys (see flv3_common.rs); the
// event side adds it to the lookup hits, so it wins only when no keyed
// filter matches.
//
// fallback = true when the charge cannot be resolved by lookups: more
// distinct shapes than FLV3_SHAPE_SLOTS, a filter expanding to more than
// FLV3_MAX_COMBINATIONS keys, or too many filters for the rank encoding. The
// event side then runs filter_lookup_fallback on flat_filters_agg, and
// `shapes` is left empty.
fn filter_lookup_plan(filters_agg: serde_json::Value) -> serde_json::Value {
    let mut shapes: std::collections::BTreeSet<Vec<&str>> = std::collections::BTreeSet::new();
    let mut oversized = false;
    let mut empty_filter_rank: Option<i64> = None;
    let empty: Vec<serde_json::Value> = Vec::new();
    let arr = filters_agg.as_array().unwrap_or(&empty);
    let order = flv3_api_order(arr);
    for (position, f) in arr.iter().enumerate() {
        let api_order = match order[position] {
            Some(o) => o,
            None => continue,
        };
        if flv3_is_empty_filter(f) {
            let rank = flv3_rank(0, api_order, position);
            empty_filter_rank = Some(empty_filter_rank.map_or(rank, |r| r.max(rank)));
            continue;
        }
        let terms = match f.get("filters").and_then(flv3_filter_terms) {
            Some(t) => t,
            None => continue,
        };
        if flv3_combinations(&terms).map_or(true, |n| n > FLV3_MAX_COMBINATIONS) {
            oversized = true;
            continue;
        }
        shapes.insert(terms.iter().map(|(k, _)| *k).collect());
    }
    let shape_count = shapes.len();
    let fallback = oversized || shape_count > FLV3_SHAPE_SLOTS || arr.len() as i64 >= FLV3_RANK_SLOT;
    let mut ordered: Vec<Vec<&str>> = if fallback { Vec::new() } else { shapes.into_iter().collect() };
    // Stable sort on top of the BTreeSet order: key count desc, then keys.
    ordered.sort_by(|a, b| b.len().cmp(&a.len()));
    let mut out = serde_json::Map::new();
    out.insert("fallback".to_string(), serde_json::Value::Bool(fallback));
    out.insert("shape_count".to_string(), serde_json::Value::from(shape_count));
    out.insert(
        "shapes".to_string(),
        serde_json::Value::Array(
            ordered
                .into_iter()
                .map(|s| serde_json::Value::Array(s.into_iter().map(serde_json::Value::from).collect()))
                .collect(),
        ),
    );
    out.insert(
        "empty_filter_rank".to_string(),
        empty_filter_rank.map_or(serde_json::Value::Null, serde_json::Value::from),
    );
    serde_json::Value::Object(out)
}
// Shared by the v3 UDF bodies (gen_sql.sh pastes this file, and the
// production json_text.rs, after each body). Helpers are prefixed flv3_ so
// they cannot collide with the production UDF helpers pulled in by tests.
//
// Selection rules: the API's ChargeFilters::EventMatchingService
// (api/app/services/events/billing_period_filters/event_matching_service.rb):
//   - a filter matches when every key is on the event and
//     `event.properties[key].to_s` is an allowed value (a JSON null reads
//     as "", Ruby's nil.to_s);
//   - a charge filter without values has an empty to_h and matches every
//     event, with 0 keys;
//   - the winner is `max_by { keys.size }` over the charge's filters in
//     ChargeFilter's default_scope order (updated_at ASC): most keys wins,
//     then the least recently updated. Filters with the same updated_at are
//     in no defined order in Postgres; the id decides here.
//
// Lookup key of one (filter, value combination), and of one (event, shape):
//   key    = ( str(filter_key) str(value) )*   over the keys in byte order
//   str(x) = <octet_len> ':' <bytes>
// Length prefixes make the encoding unambiguous without escaping, so two
// different combinations can never produce the same key. A key always has at
// least one term, so it is never the empty string (the event side uses ""
// for "this shape does not apply").

// Event-side shape slots: one temporal-join lookup per slot in
// ../../sql/03_enrichment_v3.sql. MUST equal the number of lookup joins there.
const FLV3_SHAPE_SLOTS: usize = 8;

// A filter expanding to more value combinations than this sends its charge to
// the fallback path (filter_lookup_fallback on flat_filters_agg).
// Production max on 2026-09-24: 31 combinations for one filter.
const FLV3_MAX_COMBINATIONS: usize = 256;

// rank = key_count * 1e12 + (999999 - api_order) * 1e6 + position
// The highest rank wins: most keys, then the lowest api_order (updated_at,
// id). position (the element's index in filters_agg) rides in the low digits
// so the event side can read the winner back with `rank % 1e6`; api_order is
// unique per charge, so position never decides. A charge with 1e6 filters or
// more goes to the fallback.
const FLV3_RANK_SLOT: i64 = 1_000_000;

fn flv3_rank(key_count: usize, api_order: usize, position: usize) -> i64 {
    (key_count as i64) * FLV3_RANK_SLOT * FLV3_RANK_SLOT
        + (FLV3_RANK_SLOT - 1 - api_order as i64) * FLV3_RANK_SLOT
        + position as i64
}

// Each filters_agg element's index in the API's order (updated_at ASC, then
// id), None for an element that is not a charge filter (the single row of a
// filterless charge). charge_filter_updated_at is the 'YYYY-MM-DD
// HH:MM:SS[.ffffff]' text of 02_flat_filters.sql, which sorts as text: the
// fields are fixed width and a missing fraction sorts first.
fn flv3_api_order(arr: &[serde_json::Value]) -> Vec<Option<usize>> {
    let sort_key = |i: usize| {
        (
            arr[i].get("charge_filter_updated_at").and_then(|v| v.as_str()).unwrap_or(""),
            arr[i].get("charge_filter_id").and_then(|v| v.as_str()).unwrap_or(""),
        )
    };
    let mut indices: Vec<usize> = (0..arr.len())
        .filter(|&i| arr[i].get("charge_filter_id").and_then(|v| v.as_str()).is_some())
        .collect();
    indices.sort_by(|&a, &b| sort_key(a).cmp(&sort_key(b)));
    let mut order = vec![None; arr.len()];
    for (o, i) in indices.into_iter().enumerate() {
        order[i] = Some(o);
    }
    order
}

// A charge filter without values ({"": null} in flat_filters): the API reads
// it as an empty to_h, which matches every event with 0 keys.
fn flv3_is_empty_filter(f: &serde_json::Value) -> bool {
    f.get("charge_filter_id").and_then(|v| v.as_str()).is_some()
        && f
            .get("filters")
            .and_then(|v| v.as_object())
            .map_or(false, |m| m.values().all(|v| v.is_null()))
}

// The part of one filter that keyed matching reads: its keys in byte order,
// each with its distinct allowed string values in byte order. None when the
// filter has no keys to match on (not an object, an empty or valueless
// filter: see flv3_is_empty_filter) or can never match (a key without any
// allowed value).
fn flv3_filter_terms(filters: &serde_json::Value) -> Option<Vec<(&str, Vec<&str>)>> {
    let map = filters.as_object()?;
    if map.is_empty() {
        return None;
    }
    let mut terms = Vec::with_capacity(map.len());
    for (key, allowed) in map {
        let mut values: Vec<&str> = allowed.as_array()?.iter().filter_map(|v| v.as_str()).collect();
        values.sort_unstable();
        values.dedup();
        if values.is_empty() {
            return None;
        }
        terms.push((key.as_str(), values));
    }
    terms.sort_unstable_by(|a, b| a.0.cmp(b.0));
    Some(terms)
}

// Number of lookup keys a filter expands to; None on overflow.
fn flv3_combinations(terms: &[(&str, Vec<&str>)]) -> Option<usize> {
    terms.iter().try_fold(1usize, |acc, (_, values)| acc.checked_mul(values.len()))
}

// Every lookup key of a filter: the cartesian product of its values, built
// term by term in key order.
fn flv3_lookup_keys(terms: &[(&str, Vec<&str>)]) -> Vec<String> {
    let mut keys: Vec<String> = vec![String::new()];
    for (key, values) in terms {
        let mut next = Vec::with_capacity(keys.len() * values.len());
        for prefix in &keys {
            for value in values {
                let mut k = prefix.clone();
                flv3_push_str(&mut k, key);
                flv3_push_str(&mut k, value);
                next.push(k);
            }
        }
        keys = next;
    }
    keys
}

// `event.properties[key].to_s` as the API compares it: None when the key is
// absent (or the properties are not an object), "" for JSON null, the
// production json_value_text rule otherwise.
fn flv3_property_text(properties: &serde_json::Value, key: &str) -> Option<String> {
    match properties.as_object()?.get(key)? {
        serde_json::Value::Null => Some(String::new()),
        v => Some(json_value_text(v)),
    }
}

fn flv3_push_str(out: &mut String, s: &str) {
    out.push_str(&s.len().to_string());
    out.push(':');
    out.push_str(s);
}
// The one string-conversion rule for event property values, used by both
// filter matching and grouped_by: a string is taken as-is, anything else is
// its compact JSON text (serde_json's canonical rendering).
//
// DECISION (Jeremy, 2026-08-28): plain JSON-text comparison, NOT a port of
// the Go processor's fmt.Sprintf("%v") float formatting. Numeric corner
// cases therefore render differently than the Go path (Go: 1000000 ->
// "1e+06", 0.0000001 -> "1e-07"; here: "1000000" / "1e-7") — accepted, on
// the grounds that every dialect (Go %v, JS String(), serde_json) already
// disagreed on those corners and a comparison should just be a comparison.
// Everyday values (strings, integers, plain decimals, booleans) are
// identical in all dialects.
fn json_value_text(v: &serde_json::Value) -> String {
    match v {
        serde_json::Value::String(s) => s.clone(),
        other => other.to_string(),
    }
}
$$;

CREATE FUNCTION IF NOT EXISTS filter_lookup_expand(filters_agg JSONB) RETURNS JSONB
LANGUAGE rust AS $$
// Dimension side, once per charge on CDC churn: every lookup key of the
// charge with the rank of the filter that wins it.
//
// `filters_agg` is one charge's flat_filters_agg array. Returns
//   [[lookup_key, rank], ...]
// with one entry per distinct key: filters sharing a key (same shape,
// overlapping values) collapse to the best rank, which is the filter the API
// would pick among them. Filters without values have no key (plan's
// empty_filter_rank covers them), and filters past FLV3_MAX_COMBINATIONS are
// skipped (plan then marks the charge as fallback).
//
// It takes the whole array, not one filter, because the rank depends on the
// filter's place in the charge's updated_at order (flv3_api_order).
//
// An event matches a filter exactly when the key built from the event for the
// filter's shape (filter_lookup_event_keys) is one of the filter's keys:
// every filter key is present on the event and its value text is allowed.
fn filter_lookup_expand(filters_agg: serde_json::Value) -> serde_json::Value {
    let mut best: std::collections::BTreeMap<String, i64> = std::collections::BTreeMap::new();
    let empty: Vec<serde_json::Value> = Vec::new();
    let arr = filters_agg.as_array().unwrap_or(&empty);
    let order = flv3_api_order(arr);
    for (position, f) in arr.iter().enumerate() {
        let api_order = match order[position] {
            Some(o) => o,
            None => continue,
        };
        let terms = match f.get("filters").and_then(flv3_filter_terms) {
            Some(t) => t,
            None => continue,
        };
        if flv3_combinations(&terms).map_or(true, |n| n > FLV3_MAX_COMBINATIONS) {
            continue;
        }
        let rank = flv3_rank(terms.len(), api_order, position);
        for key in flv3_lookup_keys(&terms) {
            let entry = best.entry(key).or_insert(rank);
            if rank > *entry {
                *entry = rank;
            }
        }
    }
    serde_json::Value::Array(
        best.into_iter()
            .map(|(k, r)| serde_json::Value::Array(vec![serde_json::Value::from(k), serde_json::Value::from(r)]))
            .collect(),
    )
}
// Shared by the v3 UDF bodies (gen_sql.sh pastes this file, and the
// production json_text.rs, after each body). Helpers are prefixed flv3_ so
// they cannot collide with the production UDF helpers pulled in by tests.
//
// Selection rules: the API's ChargeFilters::EventMatchingService
// (api/app/services/events/billing_period_filters/event_matching_service.rb):
//   - a filter matches when every key is on the event and
//     `event.properties[key].to_s` is an allowed value (a JSON null reads
//     as "", Ruby's nil.to_s);
//   - a charge filter without values has an empty to_h and matches every
//     event, with 0 keys;
//   - the winner is `max_by { keys.size }` over the charge's filters in
//     ChargeFilter's default_scope order (updated_at ASC): most keys wins,
//     then the least recently updated. Filters with the same updated_at are
//     in no defined order in Postgres; the id decides here.
//
// Lookup key of one (filter, value combination), and of one (event, shape):
//   key    = ( str(filter_key) str(value) )*   over the keys in byte order
//   str(x) = <octet_len> ':' <bytes>
// Length prefixes make the encoding unambiguous without escaping, so two
// different combinations can never produce the same key. A key always has at
// least one term, so it is never the empty string (the event side uses ""
// for "this shape does not apply").

// Event-side shape slots: one temporal-join lookup per slot in
// ../../sql/03_enrichment_v3.sql. MUST equal the number of lookup joins there.
const FLV3_SHAPE_SLOTS: usize = 8;

// A filter expanding to more value combinations than this sends its charge to
// the fallback path (filter_lookup_fallback on flat_filters_agg).
// Production max on 2026-09-24: 31 combinations for one filter.
const FLV3_MAX_COMBINATIONS: usize = 256;

// rank = key_count * 1e12 + (999999 - api_order) * 1e6 + position
// The highest rank wins: most keys, then the lowest api_order (updated_at,
// id). position (the element's index in filters_agg) rides in the low digits
// so the event side can read the winner back with `rank % 1e6`; api_order is
// unique per charge, so position never decides. A charge with 1e6 filters or
// more goes to the fallback.
const FLV3_RANK_SLOT: i64 = 1_000_000;

fn flv3_rank(key_count: usize, api_order: usize, position: usize) -> i64 {
    (key_count as i64) * FLV3_RANK_SLOT * FLV3_RANK_SLOT
        + (FLV3_RANK_SLOT - 1 - api_order as i64) * FLV3_RANK_SLOT
        + position as i64
}

// Each filters_agg element's index in the API's order (updated_at ASC, then
// id), None for an element that is not a charge filter (the single row of a
// filterless charge). charge_filter_updated_at is the 'YYYY-MM-DD
// HH:MM:SS[.ffffff]' text of 02_flat_filters.sql, which sorts as text: the
// fields are fixed width and a missing fraction sorts first.
fn flv3_api_order(arr: &[serde_json::Value]) -> Vec<Option<usize>> {
    let sort_key = |i: usize| {
        (
            arr[i].get("charge_filter_updated_at").and_then(|v| v.as_str()).unwrap_or(""),
            arr[i].get("charge_filter_id").and_then(|v| v.as_str()).unwrap_or(""),
        )
    };
    let mut indices: Vec<usize> = (0..arr.len())
        .filter(|&i| arr[i].get("charge_filter_id").and_then(|v| v.as_str()).is_some())
        .collect();
    indices.sort_by(|&a, &b| sort_key(a).cmp(&sort_key(b)));
    let mut order = vec![None; arr.len()];
    for (o, i) in indices.into_iter().enumerate() {
        order[i] = Some(o);
    }
    order
}

// A charge filter without values ({"": null} in flat_filters): the API reads
// it as an empty to_h, which matches every event with 0 keys.
fn flv3_is_empty_filter(f: &serde_json::Value) -> bool {
    f.get("charge_filter_id").and_then(|v| v.as_str()).is_some()
        && f
            .get("filters")
            .and_then(|v| v.as_object())
            .map_or(false, |m| m.values().all(|v| v.is_null()))
}

// The part of one filter that keyed matching reads: its keys in byte order,
// each with its distinct allowed string values in byte order. None when the
// filter has no keys to match on (not an object, an empty or valueless
// filter: see flv3_is_empty_filter) or can never match (a key without any
// allowed value).
fn flv3_filter_terms(filters: &serde_json::Value) -> Option<Vec<(&str, Vec<&str>)>> {
    let map = filters.as_object()?;
    if map.is_empty() {
        return None;
    }
    let mut terms = Vec::with_capacity(map.len());
    for (key, allowed) in map {
        let mut values: Vec<&str> = allowed.as_array()?.iter().filter_map(|v| v.as_str()).collect();
        values.sort_unstable();
        values.dedup();
        if values.is_empty() {
            return None;
        }
        terms.push((key.as_str(), values));
    }
    terms.sort_unstable_by(|a, b| a.0.cmp(b.0));
    Some(terms)
}

// Number of lookup keys a filter expands to; None on overflow.
fn flv3_combinations(terms: &[(&str, Vec<&str>)]) -> Option<usize> {
    terms.iter().try_fold(1usize, |acc, (_, values)| acc.checked_mul(values.len()))
}

// Every lookup key of a filter: the cartesian product of its values, built
// term by term in key order.
fn flv3_lookup_keys(terms: &[(&str, Vec<&str>)]) -> Vec<String> {
    let mut keys: Vec<String> = vec![String::new()];
    for (key, values) in terms {
        let mut next = Vec::with_capacity(keys.len() * values.len());
        for prefix in &keys {
            for value in values {
                let mut k = prefix.clone();
                flv3_push_str(&mut k, key);
                flv3_push_str(&mut k, value);
                next.push(k);
            }
        }
        keys = next;
    }
    keys
}

// `event.properties[key].to_s` as the API compares it: None when the key is
// absent (or the properties are not an object), "" for JSON null, the
// production json_value_text rule otherwise.
fn flv3_property_text(properties: &serde_json::Value, key: &str) -> Option<String> {
    match properties.as_object()?.get(key)? {
        serde_json::Value::Null => Some(String::new()),
        v => Some(json_value_text(v)),
    }
}

fn flv3_push_str(out: &mut String, s: &str) {
    out.push_str(&s.len().to_string());
    out.push(':');
    out.push_str(s);
}
// The one string-conversion rule for event property values, used by both
// filter matching and grouped_by: a string is taken as-is, anything else is
// its compact JSON text (serde_json's canonical rendering).
//
// DECISION (Jeremy, 2026-08-28): plain JSON-text comparison, NOT a port of
// the Go processor's fmt.Sprintf("%v") float formatting. Numeric corner
// cases therefore render differently than the Go path (Go: 1000000 ->
// "1e+06", 0.0000001 -> "1e-07"; here: "1000000" / "1e-7") — accepted, on
// the grounds that every dialect (Go %v, JS String(), serde_json) already
// disagreed on those corners and a comparison should just be a comparison.
// Everyday values (strings, integers, plain decimals, booleans) are
// identical in all dialects.
fn json_value_text(v: &serde_json::Value) -> String {
    match v {
        serde_json::Value::String(s) => s.clone(),
        other => other.to_string(),
    }
}
$$;

CREATE FUNCTION IF NOT EXISTS filter_lookup_event_keys(shapes JSONB, properties JSONB) RETURNS VARCHAR[]
LANGUAGE rust AS $$
// Event side, once per (event, charge): the lookup key of the event for each
// of the charge's shapes (filter_lookup_plan's `shapes`), in shape order.
// Inputs are small (a few key names and the event properties), so the cost
// does not depend on how many filters the charge has.
//
// Element i is "" when shape i does not apply: one of its keys is absent on
// the event, or the properties are not an object. "" is never a lookup key,
// and the caller maps it to SQL NULL so the lookup join finds nothing.
//
// Values read as the API compares them (flv3_property_text): a JSON null is
// present and reads as "".
fn filter_lookup_event_keys(shapes: serde_json::Value, properties: serde_json::Value) -> Vec<String> {
    let shapes = match shapes.as_array() {
        Some(s) => s,
        None => return Vec::new(),
    };
    shapes
        .iter()
        .map(|shape| {
            let keys = match shape.as_array() {
                Some(k) if !k.is_empty() => k,
                _ => return String::new(),
            };
            let mut out = String::new();
            for key in keys {
                let key = match key.as_str() {
                    Some(k) => k,
                    None => return String::new(),
                };
                match flv3_property_text(&properties, key) {
                    None => return String::new(),
                    Some(text) => {
                        flv3_push_str(&mut out, key);
                        flv3_push_str(&mut out, &text);
                    }
                }
            }
            out
        })
        .collect()
}
// Shared by the v3 UDF bodies (gen_sql.sh pastes this file, and the
// production json_text.rs, after each body). Helpers are prefixed flv3_ so
// they cannot collide with the production UDF helpers pulled in by tests.
//
// Selection rules: the API's ChargeFilters::EventMatchingService
// (api/app/services/events/billing_period_filters/event_matching_service.rb):
//   - a filter matches when every key is on the event and
//     `event.properties[key].to_s` is an allowed value (a JSON null reads
//     as "", Ruby's nil.to_s);
//   - a charge filter without values has an empty to_h and matches every
//     event, with 0 keys;
//   - the winner is `max_by { keys.size }` over the charge's filters in
//     ChargeFilter's default_scope order (updated_at ASC): most keys wins,
//     then the least recently updated. Filters with the same updated_at are
//     in no defined order in Postgres; the id decides here.
//
// Lookup key of one (filter, value combination), and of one (event, shape):
//   key    = ( str(filter_key) str(value) )*   over the keys in byte order
//   str(x) = <octet_len> ':' <bytes>
// Length prefixes make the encoding unambiguous without escaping, so two
// different combinations can never produce the same key. A key always has at
// least one term, so it is never the empty string (the event side uses ""
// for "this shape does not apply").

// Event-side shape slots: one temporal-join lookup per slot in
// ../../sql/03_enrichment_v3.sql. MUST equal the number of lookup joins there.
const FLV3_SHAPE_SLOTS: usize = 8;

// A filter expanding to more value combinations than this sends its charge to
// the fallback path (filter_lookup_fallback on flat_filters_agg).
// Production max on 2026-09-24: 31 combinations for one filter.
const FLV3_MAX_COMBINATIONS: usize = 256;

// rank = key_count * 1e12 + (999999 - api_order) * 1e6 + position
// The highest rank wins: most keys, then the lowest api_order (updated_at,
// id). position (the element's index in filters_agg) rides in the low digits
// so the event side can read the winner back with `rank % 1e6`; api_order is
// unique per charge, so position never decides. A charge with 1e6 filters or
// more goes to the fallback.
const FLV3_RANK_SLOT: i64 = 1_000_000;

fn flv3_rank(key_count: usize, api_order: usize, position: usize) -> i64 {
    (key_count as i64) * FLV3_RANK_SLOT * FLV3_RANK_SLOT
        + (FLV3_RANK_SLOT - 1 - api_order as i64) * FLV3_RANK_SLOT
        + position as i64
}

// Each filters_agg element's index in the API's order (updated_at ASC, then
// id), None for an element that is not a charge filter (the single row of a
// filterless charge). charge_filter_updated_at is the 'YYYY-MM-DD
// HH:MM:SS[.ffffff]' text of 02_flat_filters.sql, which sorts as text: the
// fields are fixed width and a missing fraction sorts first.
fn flv3_api_order(arr: &[serde_json::Value]) -> Vec<Option<usize>> {
    let sort_key = |i: usize| {
        (
            arr[i].get("charge_filter_updated_at").and_then(|v| v.as_str()).unwrap_or(""),
            arr[i].get("charge_filter_id").and_then(|v| v.as_str()).unwrap_or(""),
        )
    };
    let mut indices: Vec<usize> = (0..arr.len())
        .filter(|&i| arr[i].get("charge_filter_id").and_then(|v| v.as_str()).is_some())
        .collect();
    indices.sort_by(|&a, &b| sort_key(a).cmp(&sort_key(b)));
    let mut order = vec![None; arr.len()];
    for (o, i) in indices.into_iter().enumerate() {
        order[i] = Some(o);
    }
    order
}

// A charge filter without values ({"": null} in flat_filters): the API reads
// it as an empty to_h, which matches every event with 0 keys.
fn flv3_is_empty_filter(f: &serde_json::Value) -> bool {
    f.get("charge_filter_id").and_then(|v| v.as_str()).is_some()
        && f
            .get("filters")
            .and_then(|v| v.as_object())
            .map_or(false, |m| m.values().all(|v| v.is_null()))
}

// The part of one filter that keyed matching reads: its keys in byte order,
// each with its distinct allowed string values in byte order. None when the
// filter has no keys to match on (not an object, an empty or valueless
// filter: see flv3_is_empty_filter) or can never match (a key without any
// allowed value).
fn flv3_filter_terms(filters: &serde_json::Value) -> Option<Vec<(&str, Vec<&str>)>> {
    let map = filters.as_object()?;
    if map.is_empty() {
        return None;
    }
    let mut terms = Vec::with_capacity(map.len());
    for (key, allowed) in map {
        let mut values: Vec<&str> = allowed.as_array()?.iter().filter_map(|v| v.as_str()).collect();
        values.sort_unstable();
        values.dedup();
        if values.is_empty() {
            return None;
        }
        terms.push((key.as_str(), values));
    }
    terms.sort_unstable_by(|a, b| a.0.cmp(b.0));
    Some(terms)
}

// Number of lookup keys a filter expands to; None on overflow.
fn flv3_combinations(terms: &[(&str, Vec<&str>)]) -> Option<usize> {
    terms.iter().try_fold(1usize, |acc, (_, values)| acc.checked_mul(values.len()))
}

// Every lookup key of a filter: the cartesian product of its values, built
// term by term in key order.
fn flv3_lookup_keys(terms: &[(&str, Vec<&str>)]) -> Vec<String> {
    let mut keys: Vec<String> = vec![String::new()];
    for (key, values) in terms {
        let mut next = Vec::with_capacity(keys.len() * values.len());
        for prefix in &keys {
            for value in values {
                let mut k = prefix.clone();
                flv3_push_str(&mut k, key);
                flv3_push_str(&mut k, value);
                next.push(k);
            }
        }
        keys = next;
    }
    keys
}

// `event.properties[key].to_s` as the API compares it: None when the key is
// absent (or the properties are not an object), "" for JSON null, the
// production json_value_text rule otherwise.
fn flv3_property_text(properties: &serde_json::Value, key: &str) -> Option<String> {
    match properties.as_object()?.get(key)? {
        serde_json::Value::Null => Some(String::new()),
        v => Some(json_value_text(v)),
    }
}

fn flv3_push_str(out: &mut String, s: &str) {
    out.push_str(&s.len().to_string());
    out.push(':');
    out.push_str(s);
}
// The one string-conversion rule for event property values, used by both
// filter matching and grouped_by: a string is taken as-is, anything else is
// its compact JSON text (serde_json's canonical rendering).
//
// DECISION (Jeremy, 2026-08-28): plain JSON-text comparison, NOT a port of
// the Go processor's fmt.Sprintf("%v") float formatting. Numeric corner
// cases therefore render differently than the Go path (Go: 1000000 ->
// "1e+06", 0.0000001 -> "1e-07"; here: "1000000" / "1e-7") — accepted, on
// the grounds that every dialect (Go %v, JS String(), serde_json) already
// disagreed on those corners and a comparison should just be a comparison.
// Everyday values (strings, integers, plain decimals, booleans) are
// identical in all dialects.
fn json_value_text(v: &serde_json::Value) -> String {
    match v {
        serde_json::Value::String(s) => s.clone(),
        other => other.to_string(),
    }
}
$$;

CREATE FUNCTION IF NOT EXISTS filter_lookup_fallback(filters_agg JSONB, properties JSONB) RETURNS INT
LANGUAGE rust AS $$
// Event side, fallback charges only (more shapes than slots, an oversized
// filter): the same selection as the lookup path, by scanning the charge's
// whole filters_agg like production does. Only the rare fallback charges pay
// for passing the array.
//
// Returns the winner's position in filters_agg, -1 for the default bucket,
// or NULL for an empty or missing array.
fn filter_lookup_fallback(filters_agg: serde_json::Value, properties: serde_json::Value) -> Option<i32> {
    let arr = filters_agg.as_array()?;
    if arr.is_empty() {
        return None;
    }
    let order = flv3_api_order(arr);
    let mut best: Option<i64> = None;
    for (position, f) in arr.iter().enumerate() {
        let api_order = match order[position] {
            Some(o) => o,
            None => continue,
        };
        let key_count = if flv3_is_empty_filter(f) {
            0
        } else {
            let terms = match f.get("filters").and_then(flv3_filter_terms) {
                Some(t) => t,
                None => continue,
            };
            let matches = terms.iter().all(|(key, values)| {
                flv3_property_text(&properties, key).map_or(false, |text| values.binary_search(&text.as_str()).is_ok())
            });
            if !matches {
                continue;
            }
            terms.len()
        };
        let rank = flv3_rank(key_count, api_order, position);
        best = Some(best.map_or(rank, |b| b.max(rank)));
    }
    Some(best.map_or(-1, |r| (r % FLV3_RANK_SLOT) as i32))
}
// Shared by the v3 UDF bodies (gen_sql.sh pastes this file, and the
// production json_text.rs, after each body). Helpers are prefixed flv3_ so
// they cannot collide with the production UDF helpers pulled in by tests.
//
// Selection rules: the API's ChargeFilters::EventMatchingService
// (api/app/services/events/billing_period_filters/event_matching_service.rb):
//   - a filter matches when every key is on the event and
//     `event.properties[key].to_s` is an allowed value (a JSON null reads
//     as "", Ruby's nil.to_s);
//   - a charge filter without values has an empty to_h and matches every
//     event, with 0 keys;
//   - the winner is `max_by { keys.size }` over the charge's filters in
//     ChargeFilter's default_scope order (updated_at ASC): most keys wins,
//     then the least recently updated. Filters with the same updated_at are
//     in no defined order in Postgres; the id decides here.
//
// Lookup key of one (filter, value combination), and of one (event, shape):
//   key    = ( str(filter_key) str(value) )*   over the keys in byte order
//   str(x) = <octet_len> ':' <bytes>
// Length prefixes make the encoding unambiguous without escaping, so two
// different combinations can never produce the same key. A key always has at
// least one term, so it is never the empty string (the event side uses ""
// for "this shape does not apply").

// Event-side shape slots: one temporal-join lookup per slot in
// ../../sql/03_enrichment_v3.sql. MUST equal the number of lookup joins there.
const FLV3_SHAPE_SLOTS: usize = 8;

// A filter expanding to more value combinations than this sends its charge to
// the fallback path (filter_lookup_fallback on flat_filters_agg).
// Production max on 2026-09-24: 31 combinations for one filter.
const FLV3_MAX_COMBINATIONS: usize = 256;

// rank = key_count * 1e12 + (999999 - api_order) * 1e6 + position
// The highest rank wins: most keys, then the lowest api_order (updated_at,
// id). position (the element's index in filters_agg) rides in the low digits
// so the event side can read the winner back with `rank % 1e6`; api_order is
// unique per charge, so position never decides. A charge with 1e6 filters or
// more goes to the fallback.
const FLV3_RANK_SLOT: i64 = 1_000_000;

fn flv3_rank(key_count: usize, api_order: usize, position: usize) -> i64 {
    (key_count as i64) * FLV3_RANK_SLOT * FLV3_RANK_SLOT
        + (FLV3_RANK_SLOT - 1 - api_order as i64) * FLV3_RANK_SLOT
        + position as i64
}

// Each filters_agg element's index in the API's order (updated_at ASC, then
// id), None for an element that is not a charge filter (the single row of a
// filterless charge). charge_filter_updated_at is the 'YYYY-MM-DD
// HH:MM:SS[.ffffff]' text of 02_flat_filters.sql, which sorts as text: the
// fields are fixed width and a missing fraction sorts first.
fn flv3_api_order(arr: &[serde_json::Value]) -> Vec<Option<usize>> {
    let sort_key = |i: usize| {
        (
            arr[i].get("charge_filter_updated_at").and_then(|v| v.as_str()).unwrap_or(""),
            arr[i].get("charge_filter_id").and_then(|v| v.as_str()).unwrap_or(""),
        )
    };
    let mut indices: Vec<usize> = (0..arr.len())
        .filter(|&i| arr[i].get("charge_filter_id").and_then(|v| v.as_str()).is_some())
        .collect();
    indices.sort_by(|&a, &b| sort_key(a).cmp(&sort_key(b)));
    let mut order = vec![None; arr.len()];
    for (o, i) in indices.into_iter().enumerate() {
        order[i] = Some(o);
    }
    order
}

// A charge filter without values ({"": null} in flat_filters): the API reads
// it as an empty to_h, which matches every event with 0 keys.
fn flv3_is_empty_filter(f: &serde_json::Value) -> bool {
    f.get("charge_filter_id").and_then(|v| v.as_str()).is_some()
        && f
            .get("filters")
            .and_then(|v| v.as_object())
            .map_or(false, |m| m.values().all(|v| v.is_null()))
}

// The part of one filter that keyed matching reads: its keys in byte order,
// each with its distinct allowed string values in byte order. None when the
// filter has no keys to match on (not an object, an empty or valueless
// filter: see flv3_is_empty_filter) or can never match (a key without any
// allowed value).
fn flv3_filter_terms(filters: &serde_json::Value) -> Option<Vec<(&str, Vec<&str>)>> {
    let map = filters.as_object()?;
    if map.is_empty() {
        return None;
    }
    let mut terms = Vec::with_capacity(map.len());
    for (key, allowed) in map {
        let mut values: Vec<&str> = allowed.as_array()?.iter().filter_map(|v| v.as_str()).collect();
        values.sort_unstable();
        values.dedup();
        if values.is_empty() {
            return None;
        }
        terms.push((key.as_str(), values));
    }
    terms.sort_unstable_by(|a, b| a.0.cmp(b.0));
    Some(terms)
}

// Number of lookup keys a filter expands to; None on overflow.
fn flv3_combinations(terms: &[(&str, Vec<&str>)]) -> Option<usize> {
    terms.iter().try_fold(1usize, |acc, (_, values)| acc.checked_mul(values.len()))
}

// Every lookup key of a filter: the cartesian product of its values, built
// term by term in key order.
fn flv3_lookup_keys(terms: &[(&str, Vec<&str>)]) -> Vec<String> {
    let mut keys: Vec<String> = vec![String::new()];
    for (key, values) in terms {
        let mut next = Vec::with_capacity(keys.len() * values.len());
        for prefix in &keys {
            for value in values {
                let mut k = prefix.clone();
                flv3_push_str(&mut k, key);
                flv3_push_str(&mut k, value);
                next.push(k);
            }
        }
        keys = next;
    }
    keys
}

// `event.properties[key].to_s` as the API compares it: None when the key is
// absent (or the properties are not an object), "" for JSON null, the
// production json_value_text rule otherwise.
fn flv3_property_text(properties: &serde_json::Value, key: &str) -> Option<String> {
    match properties.as_object()?.get(key)? {
        serde_json::Value::Null => Some(String::new()),
        v => Some(json_value_text(v)),
    }
}

fn flv3_push_str(out: &mut String, s: &str) {
    out.push_str(&s.len().to_string());
    out.push(':');
    out.push_str(s);
}
// The one string-conversion rule for event property values, used by both
// filter matching and grouped_by: a string is taken as-is, anything else is
// its compact JSON text (serde_json's canonical rendering).
//
// DECISION (Jeremy, 2026-08-28): plain JSON-text comparison, NOT a port of
// the Go processor's fmt.Sprintf("%v") float formatting. Numeric corner
// cases therefore render differently than the Go path (Go: 1000000 ->
// "1e+06", 0.0000001 -> "1e-07"; here: "1000000" / "1e-7") — accepted, on
// the grounds that every dialect (Go %v, JS String(), serde_json) already
// disagreed on those corners and a comparison should just be a comparison.
// Everyday values (strings, integers, plain decimals, booleans) are
// identical in all dialects.
fn json_value_text(v: &serde_json::Value) -> String {
    match v {
        serde_json::Value::String(s) => s.clone(),
        other => other.to_string(),
    }
}
$$;
