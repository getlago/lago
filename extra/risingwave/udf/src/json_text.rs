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
