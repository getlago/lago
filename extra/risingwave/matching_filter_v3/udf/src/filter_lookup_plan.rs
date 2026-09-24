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
