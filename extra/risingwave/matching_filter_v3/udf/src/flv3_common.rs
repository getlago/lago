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
