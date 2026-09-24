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
