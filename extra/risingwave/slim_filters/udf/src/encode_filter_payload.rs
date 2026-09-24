// Dimension-side encoder for match_filter_position (see that file for the
// format). Runs once per charge on CDC churn, never per event.
//
// `filters` is one charge's `flat_filters_agg.filters_agg` array, in its
// charge_filter_key order: position N of the payload is element N of the
// array, which is how the event side reads the winner back
// (`filters_agg -> position`).
//
// Only what matching reads is kept: each element's `filters` map. Values that
// are not JSON strings are dropped — matching compares with `as_str()`, so
// they can never match anyway. A non-array value list (the `{"": null}`
// encoding of a charge filter without values) becomes the `n` marker: a key
// that never matches.
fn encode_filter_payload(filters: serde_json::Value) -> String {
    let mut out = String::new();
    let arr = match filters.as_array() {
        Some(a) => a,
        None => return out,
    };
    for f in arr {
        let mut body = String::new();
        match f.get("filters").and_then(|v| v.as_object()) {
            Some(m) => {
                body.push_str(&m.len().to_string());
                body.push(';');
                for (key, allowed) in m {
                    ep_push_str(&mut body, key);
                    match allowed.as_array() {
                        Some(values) => {
                            let strings: Vec<&str> = values.iter().filter_map(|v| v.as_str()).collect();
                            body.push_str(&strings.len().to_string());
                            body.push(';');
                            for s in strings {
                                ep_push_str(&mut body, s);
                            }
                        }
                        None => body.push('n'),
                    }
                }
            }
            // No filters map (filterless charge / null): zero keys, which
            // the matcher treats as HasFilters == false.
            None => body.push_str("0;"),
        }
        ep_push_str(&mut out, &body);
    }
    out
}

// str(x) = <octet_len> ':' <bytes>
fn ep_push_str(out: &mut String, s: &str) {
    out.push_str(&s.len().to_string());
    out.push(':');
    out.push_str(s);
}
