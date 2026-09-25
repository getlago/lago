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
