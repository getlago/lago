-- GENERATED FILE — DO NOT EDIT BY HAND.
-- Source of truth: extra/risingwave/slim_filters/udf/src/*.rs (cargo test
-- runs a parity suite against the production matching_filter); regenerate
-- with extra/risingwave/slim_filters/udf/gen_sql.sh.
--
-- encode_filter_payload runs on the dimension side (CDC churn only) and
-- turns a charge's filters_agg into a compact length-prefixed VARCHAR.
-- match_filter_position runs per (event, charge) on that VARCHAR and returns
-- the winner's position in filters_agg (-1 = default bucket), so the big
-- JSONB never crosses the WASM boundary on the event path.

CREATE FUNCTION IF NOT EXISTS encode_filter_payload(filters JSONB) RETURNS VARCHAR
LANGUAGE rust AS $$
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
$$;

CREATE FUNCTION IF NOT EXISTS match_filter_position(payload VARCHAR, properties JSONB) RETURNS INT
LANGUAGE rust AS $$
// Event-side replacement for matching_filter (../../udf/src/matching_filter.rs):
// same selection rules — a filter matches when every key is present on the
// event (JSON null counts as absent) and the property's JSON text is one of
// the allowed values; most keys wins; the FIRST of equally-specific matches
// wins; no match -> default bucket — but it reads a compact, length-prefixed
// VARCHAR instead of the full filters_agg JSONB, and returns only the
// winner's POSITION. The caller reads the winner back with
// `filters_agg -> position` on the host, outside WASM.
//
// Why: matching_filter received the whole candidate array per event. With
// thousands of filters on a charge, rendering that JSONB to text, copying it
// into WASM and building a serde_json tree dominated the per-event cost. This
// scans bytes in place, with no allocation per filter, and skips a
// non-matching filter's remaining bytes in O(1).
//
// Payload format, produced by encode_filter_payload:
//   payload = filter*
//   filter  = str(body)
//   body    = <nkeys> ';' ( str(key) values ){nkeys}
//   values  = <nvalues> ';' str(value){nvalues}  |  'n'   (never matches)
//   str(x)  = <octet_len> ':' <bytes>
// Length prefixes mean no escaping: user values may contain any byte.
//
// Returns the 0-based position of the winning filter, -1 for the default
// bucket, or NULL for an empty or malformed payload (matching_filter returns
// NULL for an empty candidate array; a malformed payload cannot come out of
// the encoder).
fn match_filter_position(payload: &str, properties: serde_json::Value) -> Option<i32> {
    // Property texts, computed once per event instead of once per filter key.
    let mut props: Vec<(&str, std::borrow::Cow<str>)> = Vec::new();
    if let Some(obj) = properties.as_object() {
        for (k, v) in obj {
            match v {
                serde_json::Value::Null => {}
                serde_json::Value::String(s) => props.push((k.as_str(), std::borrow::Cow::Borrowed(s.as_str()))),
                other => props.push((k.as_str(), std::borrow::Cow::Owned(other.to_string()))),
            }
        }
    }

    let bytes = payload.as_bytes();
    let mut pos = 0usize;
    let mut index: i32 = 0;
    let mut best: i32 = -1;
    let mut best_keys: usize = 0;

    while pos < bytes.len() {
        let (body_start, body_end) = mfp_read_str(bytes, pos)?;
        pos = body_end;
        if let Some(nkeys) = mfp_filter_matches(payload, body_start, body_end, &props)? {
            // Strictly greater: the first of equally-specific matches is kept.
            if best < 0 || nkeys > best_keys {
                best = index;
                best_keys = nkeys;
            }
        }
        index += 1;
    }

    if index == 0 {
        None
    } else {
        Some(best)
    }
}

// Outer Option: None = malformed. Inner: Some(nkeys) when the filter has at
// least one key and matches the event, None otherwise.
fn mfp_filter_matches(
    payload: &str,
    start: usize,
    end: usize,
    props: &[(&str, std::borrow::Cow<str>)],
) -> Option<Option<usize>> {
    let bytes = payload.as_bytes();
    let (nkeys, mut pos) = mfp_read_int(bytes, start, b';')?;
    // HasFilters == false: never selected.
    if nkeys == 0 {
        return Some(None);
    }
    for _ in 0..nkeys {
        let (ks, ke) = mfp_read_str(bytes, pos)?;
        let key = payload.get(ks..ke)?;
        pos = ke;
        let prop = props.iter().find(|(k, _)| *k == key).map(|(_, v)| v.as_ref());
        if *bytes.get(pos)? == b'n' {
            // Null value list: this key, hence the filter, never matches.
            return Some(None);
        }
        let (nvalues, mut vpos) = mfp_read_int(bytes, pos, b';')?;
        let prop = match prop {
            Some(p) => p,
            // Key absent or null on the event: no match. The body is
            // length-framed, so the rest of it is skipped for free.
            None => return Some(None),
        };
        let mut contained = false;
        for _ in 0..nvalues {
            let (vs, ve) = mfp_read_str(bytes, vpos)?;
            if !contained && &bytes[vs..ve] == prop.as_bytes() {
                contained = true;
            }
            vpos = ve;
        }
        if !contained {
            return Some(None);
        }
        pos = vpos;
    }
    if pos != end {
        return None;
    }
    Some(Some(nkeys))
}

// <decimal> <terminator> -> (value, position after the terminator)
fn mfp_read_int(bytes: &[u8], mut pos: usize, terminator: u8) -> Option<(usize, usize)> {
    let start = pos;
    let mut n: usize = 0;
    while pos < bytes.len() && bytes[pos].is_ascii_digit() {
        n = n.checked_mul(10)?.checked_add((bytes[pos] - b'0') as usize)?;
        pos += 1;
    }
    if pos == start || pos >= bytes.len() || bytes[pos] != terminator {
        return None;
    }
    Some((n, pos + 1))
}

// str(x) at `pos` -> (content start, content end)
fn mfp_read_str(bytes: &[u8], pos: usize) -> Option<(usize, usize)> {
    let (len, start) = mfp_read_int(bytes, pos, b':')?;
    let end = start.checked_add(len)?;
    if end > bytes.len() {
        return None;
    }
    Some((start, end))
}
$$;
