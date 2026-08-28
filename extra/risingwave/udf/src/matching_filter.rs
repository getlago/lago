// Port of models.MatchingFilter (events-processor, models/flat_filters.go:180)
// plus its helpers HasFilters, IsMatchingEvent and ToDefaultFilter. The
// selection logic (match, most-keys-wins, default-bucket fallback) follows Go
// exactly; property values compare by their JSON TEXT (see json_text.rs), a
// deliberate simplification over Go's %v float formatting.
//
// `filters` is ONE charge's flat_filters rows aggregated into a JSONB array
// ordered by charge_filter_key (the deterministic stand-in for Go's
// unspecified DB row order — the Go code reads filters[0] for the default
// bucket, which is row-order dependent there). Each element carries:
//   charge_filter_id, charge_filter_updated_at, filters, pricing_group_keys
//
// Returns the winning element as-is, or the charge's default bucket
// (ToDefaultFilter: filter identity dropped, pricing_group_keys kept from the
// first candidate). Omitted keys surface as SQL NULL through -> / ->>.
// Returns NULL only for a missing/empty candidate array, which the caller
// never produces (every charge has at least one flat_filters row).
fn matching_filter(
    filters: serde_json::Value,
    properties: serde_json::Value,
) -> Option<serde_json::Value> {
    let arr = match filters.as_array() {
        Some(a) if !a.is_empty() => a,
        _ => return None,
    };

    // Multiple filters are present, identify the best match
    if arr.len() > 1 {
        // First select all matching filters
        let matching: Vec<&serde_json::Value> = arr
            .iter()
            .filter(|f| has_filters(f) && is_matching_event(f, &properties))
            .collect();

        if matching.is_empty() {
            // No filter matches the event: return the charge's default bucket
            Some(to_default_filter(&arr[0]))
        } else {
            // Multiple filters match the event (parent/child filters): take
            // only the one matching the most properties. Strictly-greater
            // replacement keeps the FIRST of equally-specific matches, like Go.
            let mut best = matching[0];
            for f in matching.iter().skip(1) {
                if filter_key_count(f) > filter_key_count(best) {
                    best = f;
                }
            }
            Some((*best).clone())
        }
    } else {
        let f = &arr[0];
        if has_filters(f) && is_matching_event(f, &properties) {
            Some(f.clone())
        } else {
            Some(to_default_filter(f))
        }
    }
}

fn filter_values(f: &serde_json::Value) -> Option<&serde_json::Map<String, serde_json::Value>> {
    f.get("filters").and_then(|v| v.as_object())
}

// FlatFilter.HasFilters: a non-null, non-empty filters map. Note that a
// charge filter without values ({"": null}, see 02_flat_filters.sql) HAS
// filters — it is a never-matching one, exactly like in Go.
fn has_filters(f: &serde_json::Value) -> bool {
    filter_values(f).map(|m| !m.is_empty()).unwrap_or(false)
}

fn filter_key_count(f: &serde_json::Value) -> usize {
    filter_values(f).map(|m| m.len()).unwrap_or(0)
}

// FlatFilter.IsMatchingEvent: every filter key must be present on the event
// (JSON null counts as absent, like Go's nil) and its JSON-text value must
// be contained in the allowed list.
fn is_matching_event(f: &serde_json::Value, properties: &serde_json::Value) -> bool {
    let values = match filter_values(f) {
        Some(m) => m,
        None => return true,
    };
    for (key, allowed) in values {
        let prop = match properties.get(key) {
            None | Some(serde_json::Value::Null) => return false,
            Some(v) => v,
        };
        let formatted = json_value_text(prop);
        let contained = allowed
            .as_array()
            .map(|a| a.iter().any(|x| x.as_str() == Some(formatted.as_str())))
            // null values ({"": null}) never match — Go's slices.Contains(nil, x)
            .unwrap_or(false);
        if !contained {
            return false;
        }
    }
    true
}

// FlatFilter.ToDefaultFilter: the default bucket keeps only
// pricing_group_keys (from the candidate it is derived from — filters[0] at
// the call sites); charge_filter_id / charge_filter_updated_at / filters are
// omitted so they read back as SQL NULL.
fn to_default_filter(f: &serde_json::Value) -> serde_json::Value {
    let mut out = serde_json::Map::new();
    if let Some(pgk) = f.get("pricing_group_keys") {
        if !pgk.is_null() {
            out.insert("pricing_group_keys".to_string(), pgk.clone());
        }
    }
    serde_json::Value::Object(out)
}
