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
