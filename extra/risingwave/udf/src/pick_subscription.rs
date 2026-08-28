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
