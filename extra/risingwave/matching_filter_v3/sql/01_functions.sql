-- GENERATED FILE — DO NOT EDIT BY HAND.
-- Source of truth: extra/risingwave/matching_filter_v3/udf/src/*.rs (cargo
-- test runs a parity suite against the production matching_filter);
-- regenerate with extra/risingwave/matching_filter_v3/udf/gen_sql.sh.
--
-- filter_lookup_plan and filter_lookup_expand run on the dimension side (CDC
-- churn only): they turn a charge's filters_agg into its shapes and one
-- lookup key per (filter, value combination). filter_lookup_event_keys runs
-- per (event, charge) on small inputs (the charge's shapes and the event
-- properties) and returns the event's lookup key per shape, so the filter
-- list never crosses the WASM boundary on the event path.

CREATE FUNCTION IF NOT EXISTS filter_lookup_plan(filters_agg JSONB) RETURNS JSONB
LANGUAGE rust AS $$
// Dimension side, once per charge on CDC churn: decides how the charge is
// matched per event.
//
// `filters_agg` is one charge's flat_filters_agg array. Returns
//   {"fallback": bool, "shape_count": n, "shapes": [[key, ...], ...]}
// where a shape is the sorted key set of a selectable filter (see
// flv3_filter_terms). Shapes are ordered by key count desc, then by keys, so
// the output is canonical; the order does not affect the winner.
//
// fallback = true when the charge cannot be resolved by lookups: more
// distinct shapes than FLV3_SHAPE_SLOTS, or a filter expanding to more than
// FLV3_MAX_COMBINATIONS keys. The event side then runs the production
// matching_filter on flat_filters_agg, and `shapes` is left empty.
fn filter_lookup_plan(filters_agg: serde_json::Value) -> serde_json::Value {
    let mut shapes: std::collections::BTreeSet<Vec<&str>> = std::collections::BTreeSet::new();
    let mut oversized = false;
    if let Some(arr) = filters_agg.as_array() {
        for f in arr {
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
    }
    let shape_count = shapes.len();
    let fallback = oversized || shape_count > FLV3_SHAPE_SLOTS;
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
                .map(|s| serde_json::Value::Array(s.into_iter().map(|k| serde_json::Value::from(k)).collect()))
                .collect(),
        ),
    );
    serde_json::Value::Object(out)
}
// Shared by the v3 UDF bodies (gen_sql.sh pastes this file after each body
// that needs it). Helpers are prefixed flv3_ so they cannot collide with the
// production UDF helpers pulled in by the parity tests.
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
// the fallback path (production matching_filter on flat_filters_agg).
// Production max on 2026-09-24: 31 combinations for one filter.
const FLV3_MAX_COMBINATIONS: usize = 256;

fn flv3_push_str(out: &mut String, s: &str) {
    out.push_str(&s.len().to_string());
    out.push(':');
    out.push_str(s);
}

// The part of one filter that matching reads: its keys in byte order, each
// with its distinct allowed string values in byte order. None when the filter
// can never be selected by matching_filter:
//   - not an object, or an empty object (HasFilters == false);
//   - a key whose value list is not an array (the {"": null} encoding of a
//     charge filter without values);
//   - a key without any string value (non-string values never match: the
//     comparison is `x.as_str() == Some(event value text)`).
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
$$;

CREATE FUNCTION IF NOT EXISTS filter_lookup_expand(filters JSONB) RETURNS JSONB
LANGUAGE rust AS $$
// Dimension side, once per filter on CDC churn: every lookup key the filter
// matches, one per combination of its allowed values.
//
// `filters` is one flat_filters_agg element's `filters` map. Returns
//   {"key_count": n, "lookup_keys": [key, ...]}
// or NULL when the filter can never be selected (flv3_filter_terms) or
// expands past FLV3_MAX_COMBINATIONS (filter_lookup_plan then marks the
// charge as fallback, so no lookup row is needed).
//
// An event matches the filter exactly when the key built from the event for
// the filter's shape (filter_lookup_event_keys) is one of these keys: every
// filter key is present on the event and its value text is allowed.
fn filter_lookup_expand(filters: serde_json::Value) -> Option<serde_json::Value> {
    let terms = flv3_filter_terms(&filters)?;
    if flv3_combinations(&terms)? > FLV3_MAX_COMBINATIONS {
        return None;
    }
    // Cartesian product, built term by term in key order.
    let mut keys: Vec<String> = vec![String::new()];
    for (key, values) in &terms {
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
    let mut out = serde_json::Map::new();
    out.insert("key_count".to_string(), serde_json::Value::from(terms.len()));
    out.insert(
        "lookup_keys".to_string(),
        serde_json::Value::Array(keys.into_iter().map(serde_json::Value::from).collect()),
    );
    Some(serde_json::Value::Object(out))
}
// Shared by the v3 UDF bodies (gen_sql.sh pastes this file after each body
// that needs it). Helpers are prefixed flv3_ so they cannot collide with the
// production UDF helpers pulled in by the parity tests.
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
// the fallback path (production matching_filter on flat_filters_agg).
// Production max on 2026-09-24: 31 combinations for one filter.
const FLV3_MAX_COMBINATIONS: usize = 256;

fn flv3_push_str(out: &mut String, s: &str) {
    out.push_str(&s.len().to_string());
    out.push(':');
    out.push_str(s);
}

// The part of one filter that matching reads: its keys in byte order, each
// with its distinct allowed string values in byte order. None when the filter
// can never be selected by matching_filter:
//   - not an object, or an empty object (HasFilters == false);
//   - a key whose value list is not an array (the {"": null} encoding of a
//     charge filter without values);
//   - a key without any string value (non-string values never match: the
//     comparison is `x.as_str() == Some(event value text)`).
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
$$;

CREATE FUNCTION IF NOT EXISTS filter_lookup_event_keys(shapes JSONB, properties JSONB) RETURNS VARCHAR[]
LANGUAGE rust AS $$
// Event side, once per (event, charge): the lookup key of the event for each
// of the charge's shapes (filter_lookup_plan's `shapes`), in shape order.
// Inputs are small (a few key names and the event properties), so the cost
// does not depend on how many filters the charge has.
//
// Element i is "" when shape i does not apply: one of its keys is missing on
// the event or JSON null (matching_filter treats null as absent), or the
// properties are not an object. "" is never a lookup key, and the caller maps
// it to SQL NULL so the lookup join finds nothing.
//
// Property values are rendered with the production json_value_text rule
// (../../../udf/src/json_text.rs), the same text matching_filter compares.
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
                match properties.get(key) {
                    None | Some(serde_json::Value::Null) => return String::new(),
                    Some(v) => {
                        flv3_push_str(&mut out, key);
                        flv3_push_str(&mut out, &json_value_text(v));
                    }
                }
            }
            out
        })
        .collect()
}
// Shared by the v3 UDF bodies (gen_sql.sh pastes this file after each body
// that needs it). Helpers are prefixed flv3_ so they cannot collide with the
// production UDF helpers pulled in by the parity tests.
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
// the fallback path (production matching_filter on flat_filters_agg).
// Production max on 2026-09-24: 31 combinations for one filter.
const FLV3_MAX_COMBINATIONS: usize = 256;

fn flv3_push_str(out: &mut String, s: &str) {
    out.push_str(&s.len().to_string());
    out.push(':');
    out.push_str(s);
}

// The part of one filter that matching reads: its keys in byte order, each
// with its distinct allowed string values in byte order. None when the filter
// can never be selected by matching_filter:
//   - not an object, or an empty object (HasFilters == false);
//   - a key whose value list is not an array (the {"": null} encoding of a
//     charge filter without values);
//   - a key without any string value (non-string values never match: the
//     comparison is `x.as_str() == Some(event value text)`).
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
