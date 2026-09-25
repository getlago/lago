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
