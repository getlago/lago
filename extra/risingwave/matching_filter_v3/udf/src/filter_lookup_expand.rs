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
