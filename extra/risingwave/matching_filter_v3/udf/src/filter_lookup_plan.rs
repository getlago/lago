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
