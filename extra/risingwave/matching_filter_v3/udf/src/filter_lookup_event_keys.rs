// Event side, once per (event, charge): the lookup key of the event for each
// of the charge's shapes (filter_lookup_plan's `shapes`), in shape order.
// Inputs are small (a few key names and the event properties), so the cost
// does not depend on how many filters the charge has.
//
// Element i is "" when shape i does not apply: one of its keys is absent on
// the event, or the properties are not an object. "" is never a lookup key,
// and the caller maps it to SQL NULL so the lookup join finds nothing.
//
// Values read as the API compares them (flv3_property_text): a JSON null is
// present and reads as "".
fn filter_lookup_event_keys(shapes: serde_json::Value, properties: serde_json::Value) -> Vec<String> {
    let shapes = match shapes.as_array() {
        Some(s) => s,
        None => return Vec::new(),
    };
    shapes
        .iter()
        .map(|shape| {
            let keys = match shape.as_array() {
                Some(k) if !k.is_empty() => k,
                _ => return String::new(),
            };
            let mut out = String::new();
            for key in keys {
                let key = match key.as_str() {
                    Some(k) => k,
                    None => return String::new(),
                };
                match flv3_property_text(&properties, key) {
                    None => return String::new(),
                    Some(text) => {
                        flv3_push_str(&mut out, key);
                        flv3_push_str(&mut out, &text);
                    }
                }
            }
            out
        })
        .collect()
}
