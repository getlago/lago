-- GENERATED FILE — DO NOT EDIT BY HAND.
-- Source of truth: extra/risingwave/udf/src/*.rs (cargo test runs the parity
-- suite against the Go events-processor semantics); regenerate with
-- extra/risingwave/udf/gen_sql.sh.
--
-- Embedded RUST UDFs, compiled server-side to WASM by RisingWave (verified
-- on v3.0.2; only std/chrono/rust_decimal/serde_json are allowed here).
-- They replace both the JS UDFs and the stage-1 ranking operators
-- (ROADMAP §0c, 2026-08-28): matching_filter and pick_subscription port the
-- Go processor's MatchingFilter (models/flat_filters.go:180) and
-- FetchSubscription (models/subscriptions.go:26) selection loops, so stage 1
-- resolves dimension fan-out with a scalar in-memory loop instead of
-- materialized per-event ranking state. Property values compare by their
-- plain JSON TEXT (json_text.rs — a deliberate simplification over Go's %v
-- float formatting; decision recorded there and in ROADMAP §0c).
--
-- NULL handling: WASM UDFs are STRICT — a SQL NULL argument short-circuits
-- to a NULL result without calling the function. Call sites COALESCE
-- arguments where the Go code accepts nil (see 04_enrichment.sql).

CREATE FUNCTION IF NOT EXISTS matching_filter(filters JSONB, properties JSONB) RETURNS JSONB
LANGUAGE rust AS $$
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

CREATE FUNCTION IF NOT EXISTS pick_subscription(subs JSONB, event_ts DOUBLE PRECISION) RETURNS JSONB
LANGUAGE rust AS $$
// Port of ApiStore.FetchSubscription (events-processor,
// models/subscriptions.go:26):
//
//   WHERE date_trunc('millisecond', started_at) <= ts
//     AND (terminated_at IS NULL OR date_trunc('millisecond', terminated_at) >= ts)
//   ORDER BY terminated_at DESC NULLS FIRST, started_at DESC
//   LIMIT 1
//
// `subs` is every subscription row of one (organization_id, external_id),
// aggregated as a JSONB array (02_flat_filters.sql); started_at_ms /
// terminated_at_ms are already millisecond-floored there, mirroring the
// date_trunc. event_ts is the raw event timestamp in float seconds — Go
// passes it untruncated.
//
// Returns the winning element (its id / customer_id / plan_id are read with
// ->>), or NULL when no subscription is valid at the event timestamp — the
// row then stays subscription-less and gets no charge fan-out, exactly like
// the Go processor's nil-subscription path.
fn pick_subscription(subs: serde_json::Value, event_ts: f64) -> Option<serde_json::Value> {
    let arr = subs.as_array()?;
    let event_ms = event_ts * 1000.0;

    let mut best: Option<&serde_json::Value> = None;
    for sub in arr {
        let started_ms = match sub.get("started_at_ms").and_then(|v| v.as_f64()) {
            Some(v) => v,
            // started_at NULL never qualifies (SQL: NULL <= ts is not true)
            None => continue,
        };
        if started_ms > event_ms {
            continue;
        }
        if let Some(terminated_ms) = sub.get("terminated_at_ms").and_then(|v| v.as_f64()) {
            if terminated_ms < event_ms {
                continue;
            }
        }
        best = Some(match best {
            None => sub,
            Some(current) => {
                if sub_beats(sub, current) {
                    sub
                } else {
                    current
                }
            }
        });
    }
    best.cloned()
}

// ORDER BY terminated_at DESC NULLS FIRST, started_at DESC, with id ASC as
// the deterministic final tie-break (Postgres leaves full ties unspecified;
// the processor's badger-cache path iterates keys in id order, so id ASC is
// the faithful choice).
fn sub_beats(a: &serde_json::Value, b: &serde_json::Value) -> bool {
    let a_term = a.get("terminated_at_ms").and_then(|v| v.as_f64());
    let b_term = b.get("terminated_at_ms").and_then(|v| v.as_f64());
    match (a_term, b_term) {
        (None, Some(_)) => return true,
        (Some(_), None) => return false,
        (Some(x), Some(y)) if x != y => return x > y,
        _ => {}
    }
    let a_start = a.get("started_at_ms").and_then(|v| v.as_f64()).unwrap_or(f64::NEG_INFINITY);
    let b_start = b.get("started_at_ms").and_then(|v| v.as_f64()).unwrap_or(f64::NEG_INFINITY);
    if a_start != b_start {
        return a_start > b_start;
    }
    let a_id = a.get("id").and_then(|v| v.as_str()).unwrap_or("");
    let b_id = b.get("id").and_then(|v| v.as_str()).unwrap_or("");
    a_id < b_id
}
$$;

CREATE FUNCTION IF NOT EXISTS extract_grouped_by(pricing_group_keys JSONB, properties JSONB, accepts_target_wallet BOOLEAN) RETURNS JSONB
LANGUAGE rust AS $$
// Port of enrichWithPricingGroupKeys (events-processor,
// processors/events_processor/enrichment_service.go:193): builds the
// grouped_by map from the winning filter's pricing_group_keys plus the
// target_wallet_code special key. Values are rendered as JSON text (see
// json_text.rs); a missing or null property maps to "" (but
// target_wallet_code is only set when present and non-null).
fn extract_grouped_by(
    pricing_group_keys: serde_json::Value,
    properties: serde_json::Value,
    accepts_target_wallet: bool,
) -> serde_json::Value {
    let mut out = serde_json::Map::new();
    if let Some(keys) = pricing_group_keys.as_array() {
        for key in keys {
            if let Some(key) = key.as_str() {
                let value = match properties.get(key) {
                    None | Some(serde_json::Value::Null) => String::new(),
                    Some(v) => json_value_text(v),
                };
                out.insert(key.to_string(), serde_json::Value::String(value));
            }
        }
    }
    if accepts_target_wallet {
        if let Some(v) = properties.get("target_wallet_code") {
            if !v.is_null() {
                out.insert(
                    "target_wallet_code".to_string(),
                    serde_json::Value::String(json_value_text(v)),
                );
            }
        }
    }
    serde_json::Value::Object(out)
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
