// Same layout rule as ../../udf/src/lib.rs: the UDF bodies are plain
// top-level items so gen_sql.sh can paste each file verbatim into a
// CREATE FUNCTION body (which must START with the `fn` named like the SQL
// function). Shared helpers live in flv3_common.rs, which uses the
// production json_value_text rule.
include!("filter_lookup_plan.rs");
include!("filter_lookup_expand.rs");
include!("filter_lookup_event_keys.rs");
include!("filter_lookup_fallback.rs");
include!("flv3_common.rs");
include!("../../../udf/src/json_text.rs");

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::{json, Value};
    use std::collections::HashMap;

    // The production RisingWave UDF, for the tests pinning where v3 differs.
    include!("../../../udf/src/matching_filter.rs");

    // ---- the reference: a port of the API's per-event selection ----
    //
    // Events::BillingPeriodFilters::EventMatchingService, written as close to
    // the Ruby as possible and without the flv3_ helpers:
    //
    //   matching = charge.filters.select { |f| f.to_h.all? { |k, v|
    //     props.key?(k) && props[k].to_s.in?(v) } }
    //   matching.max_by { |f| f.to_h.keys.size }
    //
    // charge.filters is ordered by updated_at ASC (ChargeFilter
    // default_scope); the id breaks equal timestamps. Returns the winner's
    // position in filters_agg, -1 when no filter matches.
    fn api_reference(filters_agg: &Value, properties: &Value) -> i64 {
        let arr = filters_agg.as_array().unwrap();
        let mut filters: Vec<(usize, &Value)> =
            arr.iter().enumerate().filter(|(_, f)| f["charge_filter_id"].is_string()).collect();
        filters.sort_by_key(|(_, f)| {
            (
                f["charge_filter_updated_at"].as_str().unwrap().to_string(),
                f["charge_filter_id"].as_str().unwrap().to_string(),
            )
        });
        // to_h: a filter without values ({"": null}) is an empty hash.
        let to_h = |f: &Value| -> Vec<(String, Vec<String>)> {
            f["filters"]
                .as_object()
                .map(|m| {
                    m.iter()
                        .filter(|(_, v)| !v.is_null())
                        .map(|(k, v)| {
                            (k.clone(), v.as_array().unwrap().iter().filter_map(|x| x.as_str().map(String::from)).collect())
                        })
                        .collect()
                })
                .unwrap_or_default()
        };
        // Ruby's to_s: strings as-is, nil as "", other values as JSON text.
        let to_s = |v: &Value| match v {
            Value::String(s) => s.clone(),
            Value::Null => String::new(),
            other => other.to_string(),
        };
        let mut best: Option<(usize, usize)> = None; // (key count, position)
        for (position, f) in filters {
            let h = to_h(f);
            let matches = h.iter().all(|(k, allowed)| match properties.as_object().and_then(|p| p.get(k)) {
                Some(v) => allowed.contains(&to_s(v)),
                None => false,
            });
            // max_by keeps the first maximum it meets.
            if matches && best.map_or(true, |(n, _)| h.len() > n) {
                best = Some((h.len(), position));
            }
        }
        best.map_or(-1, |(_, p)| p as i64)
    }

    #[derive(Debug, PartialEq)]
    enum V3 {
        Fallback,
        // Winner position in filters_agg, -1 for the default bucket.
        Position(i64),
    }

    // The v3 lookup path in memory: plan + expand (the filter_lookup rows),
    // the event keys, one lookup per slot, the empty filter's rank, then the
    // best rank, like GREATEST in 03_enrichment_v3.sql.
    fn resolve_v3(filters_agg: &Value, properties: &Value) -> V3 {
        let plan = filter_lookup_plan(filters_agg.clone());
        if plan["fallback"] == json!(true) {
            return V3::Fallback;
        }
        let mut lookup: HashMap<String, i64> = HashMap::new();
        for pair in filter_lookup_expand(filters_agg.clone()).as_array().unwrap() {
            let previous = lookup.insert(pair[0].as_str().unwrap().to_string(), pair[1].as_i64().unwrap());
            assert!(previous.is_none(), "duplicate lookup key {pair}");
        }
        let keys = filter_lookup_event_keys(plan["shapes"].clone(), properties.clone());
        assert!(keys.len() <= FLV3_SHAPE_SLOTS);
        let best = keys
            .iter()
            .filter(|k| !k.is_empty())
            .filter_map(|k| lookup.get(k).copied())
            .chain(plan["empty_filter_rank"].as_i64())
            .max();
        V3::Position(best.map_or(-1, |r| r % FLV3_RANK_SLOT))
    }

    // Both v3 paths (lookup and fallback) must pick the API's winner.
    fn assert_parity(filters_agg: &Value, properties: &Value) -> i64 {
        let expected = api_reference(filters_agg, properties);
        let fallback = filter_lookup_fallback(filters_agg.clone(), properties.clone()).map(i64::from);
        assert_eq!(fallback, Some(expected), "fallback vs API on {properties}");
        match resolve_v3(filters_agg, properties) {
            V3::Position(p) => assert_eq!(p, expected, "lookup vs API on {properties}"),
            V3::Fallback => {}
        }
        expected
    }

    // Filters are updated in list order unless a test says otherwise.
    fn f(id: &str, filters: Value) -> Value {
        f_at(id, "2026-08-28 10:00:00", filters)
    }

    fn f_at(id: &str, updated_at: &str, filters: Value) -> Value {
        json!({
            "charge_filter_id": id,
            "charge_filter_updated_at": updated_at,
            "filters": filters,
            "pricing_group_keys": ["region"]
        })
    }

    // ---- basic matching ----

    #[test]
    fn single_non_matching_filter_is_default() {
        let arr = json!([f("cf1", json!({"scheme": ["mastercard", "visa"]}))]);
        assert_eq!(assert_parity(&arr, &json!({"scheme": "maestro"})), -1);
    }

    #[test]
    fn single_matching_filter() {
        let arr = json!([f("cf1", json!({"scheme": ["mastercard", "visa"]}))]);
        assert_eq!(assert_parity(&arr, &json!({"scheme": "visa"})), 0);
    }

    #[test]
    fn matching_filter_among_multiple() {
        let arr = json!([f("cf1", json!({"scheme": ["visa"]})), f("cf2", json!({"scheme": ["mastercard"]}))]);
        assert_eq!(assert_parity(&arr, &json!({"scheme": "mastercard"})), 1);
        assert_eq!(assert_parity(&arr, &json!({"scheme": "maestro"})), -1);
    }

    #[test]
    fn most_keys_wins_in_both_orders() {
        let parent = f("parent", json!({"scheme": ["mastercard"]}));
        let child = f("child", json!({"scheme": ["mastercard"], "method": ["debit", "credit"]}));
        let props = json!({"scheme": "mastercard", "method": "debit"});
        assert_eq!(assert_parity(&json!([parent.clone(), child.clone()]), &props), 1);
        assert_eq!(assert_parity(&json!([child, parent]), &props), 0);
    }

    #[test]
    fn missing_property_does_not_match() {
        let arr = json!([f("cf1", json!({"scheme": ["visa"], "country": ["us"]}))]);
        assert_eq!(assert_parity(&arr, &json!({"scheme": "visa"})), -1);
    }

    #[test]
    fn filterless_charge_is_default() {
        let arr = json!([{
            "charge_filter_id": null,
            "charge_filter_updated_at": null,
            "filters": null,
            "pricing_group_keys": null
        }]);
        assert_eq!(assert_parity(&arr, &json!({"scheme": "visa"})), -1);
        assert_eq!(
            filter_lookup_plan(arr),
            json!({"fallback": false, "shape_count": 0, "shapes": [], "empty_filter_rank": null})
        );
    }

    #[test]
    fn numeric_and_boolean_properties_match_by_text() {
        let arr = json!([f("cf1", json!({"tier": ["12"]})), f("cf2", json!({"tier": ["12.5"]})), f("cf3", json!({"flag": ["true"]}))]);
        assert_eq!(assert_parity(&arr, &json!({"tier": 12})), 0);
        assert_eq!(assert_parity(&arr, &json!({"tier": 12.5})), 1);
        assert_eq!(assert_parity(&arr, &json!({"flag": true})), 2);
        assert_eq!(assert_parity(&arr, &json!({"tier": 1000000})), -1);
    }

    #[test]
    fn non_object_properties_match_nothing() {
        let arr = json!([f("cf1", json!({"scheme": ["visa"]}))]);
        assert_eq!(assert_parity(&arr, &json!(["visa"])), -1);
        assert_eq!(assert_parity(&arr, &json!("visa")), -1);
    }

    #[test]
    fn empty_value_list_never_matches() {
        let arr = json!([f("cf1", json!({"k": []})), f("cf2", json!({"k": ["v"]}))]);
        assert_eq!(assert_parity(&arr, &json!({"k": "v"})), 1);
        assert_eq!(assert_parity(&arr, &json!({"k": ""})), -1);
    }

    #[test]
    fn separators_and_digits_inside_values_are_safe() {
        let tricky = ["3:abc", ";", ":", "12:", "1:k", "", "1:x1:y"];
        for (i, v) in tricky.iter().enumerate() {
            let arr = json!([
                f("decoy", json!({"k": ["other"]})),
                f("cf", json!({"k": [v], "1:k": [v]}))
            ]);
            assert_eq!(assert_parity(&arr, &json!({"k": v, "1:k": v})), 1, "case {i}: {v:?}");
            assert_eq!(assert_parity(&arr, &json!({"k": v})), -1, "case {i}: {v:?}");
        }
    }

    #[test]
    fn multibyte_utf8() {
        let arr = json!([f("cf1", json!({"région": ["île-de-France", "日本"]}))]);
        assert_eq!(assert_parity(&arr, &json!({"région": "日本"})), 0);
        assert_eq!(assert_parity(&arr, &json!({"région": "日"})), -1);
    }

    // ---- the API's rules, where they differ from production RisingWave ----

    #[test]
    fn tie_goes_to_the_least_recently_updated_filter() {
        // filters_agg is ordered by charge_filter_id; the API list by updated_at.
        let arr = json!([
            f_at("cf_a", "2026-09-02 10:00:00", json!({"model": ["gpt4", "gpt4o"]})),
            f_at("cf_b", "2026-09-01 10:00:00", json!({"model": ["gpt4"]}))
        ]);
        let props = json!({"model": "gpt4"});
        assert_eq!(assert_parity(&arr, &props), 1);
        // Production RisingWave keeps the first in filters_agg order instead.
        assert_eq!(matching_filter(arr.clone(), props).unwrap()["charge_filter_id"], json!("cf_a"));
    }

    #[test]
    fn same_updated_at_falls_back_to_the_id() {
        let arr = json!([
            f_at("cf_b", "2026-09-01 10:00:00", json!({"a": ["x"]})),
            f_at("cf_a", "2026-09-01 10:00:00", json!({"b": ["x"]}))
        ]);
        assert_eq!(assert_parity(&arr, &json!({"a": "x", "b": "x"})), 1);
    }

    #[test]
    fn fractional_seconds_order_correctly() {
        let arr = json!([
            f_at("cf1", "2026-09-01 10:00:00.5", json!({"a": ["x"]})),
            f_at("cf2", "2026-09-01 10:00:00.25", json!({"a": ["x"]})),
            f_at("cf3", "2026-09-01 10:00:00", json!({"a": ["x"]}))
        ]);
        assert_eq!(assert_parity(&arr, &json!({"a": "x"})), 2);
    }

    #[test]
    fn valueless_filter_matches_every_event_with_zero_keys() {
        // {"": null} is the flat_filters encoding of a charge filter without
        // values. Its to_h is empty, so the API picks it over the default
        // bucket, but any keyed match beats it.
        let arr = json!([f("cf_empty", json!({"": null})), f("cf_k", json!({"k": ["v"]}))]);
        assert_eq!(assert_parity(&arr, &json!({"other": 1})), 0);
        assert_eq!(assert_parity(&arr, &json!({})), 0);
        assert_eq!(assert_parity(&arr, &json!({"k": "v"})), 1);
        // Production RisingWave never matches it.
        assert_eq!(matching_filter(arr.clone(), json!({})).unwrap()["charge_filter_id"], Value::Null);
    }

    #[test]
    fn older_valueless_filter_wins_among_valueless() {
        let arr = json!([
            f_at("cf1", "2026-09-02 10:00:00", json!({"": null})),
            f_at("cf2", "2026-09-01 10:00:00", json!({"": null}))
        ]);
        assert_eq!(assert_parity(&arr, &json!({})), 1);
    }

    #[test]
    fn json_null_property_reads_as_empty_string() {
        let arr = json!([f("cf1", json!({"k": [""]})), f("cf2", json!({"j": ["x"]}))]);
        assert_eq!(assert_parity(&arr, &json!({"k": null})), 0);
        assert_eq!(assert_parity(&arr, &json!({"j": null})), -1);
        // Production RisingWave treats null as absent.
        assert_eq!(matching_filter(arr.clone(), json!({"k": null})).unwrap()["charge_filter_id"], Value::Null);
    }

    // ---- the lookup encoding and the fallback rules ----

    #[test]
    fn lookup_rows_are_pinned() {
        let arr = json!([
            f_at("cf1", "2026-09-02 10:00:00", json!({"model": ["b", "a", "a"], "t": ["in"]})),
            f_at("cf2", "2026-09-01 10:00:00", json!({"model": ["a"], "t": ["in"]}))
        ]);
        // cf2 (older, position 1) wins the shared key; cf1 keeps the other.
        let rank_cf2 = 2 * FLV3_RANK_SLOT * FLV3_RANK_SLOT + (FLV3_RANK_SLOT - 1) * FLV3_RANK_SLOT + 1;
        let rank_cf1 = 2 * FLV3_RANK_SLOT * FLV3_RANK_SLOT + (FLV3_RANK_SLOT - 2) * FLV3_RANK_SLOT;
        assert_eq!(
            filter_lookup_expand(arr),
            json!([["5:model1:a1:t2:in", rank_cf2], ["5:model1:b1:t2:in", rank_cf1]])
        );
        let keys = filter_lookup_event_keys(json!([["model", "t"], ["t"]]), json!({"t": "in", "model": "a"}));
        assert_eq!(keys, vec!["5:model1:a1:t2:in".to_string(), "1:t2:in".to_string()]);
        assert_eq!(filter_lookup_event_keys(json!([["model", "t"]]), json!({"t": "in"})), vec![String::new()]);
        assert_eq!(filter_lookup_event_keys(json!([["t"]]), json!({"t": null})), vec!["1:t0:".to_string()]);
    }

    #[test]
    fn shapes_are_canonical() {
        let arr = json!([
            f("a", json!({"t": ["x"]})),
            f("b", json!({"t": ["y"], "model": ["m"]})),
            f("c", json!({"model": ["n"], "t": ["z"]})),
            f("d", json!({"a": ["x"]})),
            f("e", json!({"": null}))
        ]);
        let plan = filter_lookup_plan(arr);
        assert_eq!(plan["shapes"], json!([["model", "t"], ["a"], ["t"]]));
        assert_eq!(plan["shape_count"], json!(3));
        assert_eq!(plan["empty_filter_rank"], json!(flv3_rank(0, 4, 4)));
    }

    #[test]
    fn more_shapes_than_slots_falls_back() {
        let keys = ["a", "b", "c", "d", "e", "f", "g", "h", "i"];
        let arr: Vec<Value> = keys.iter().map(|k| f(k, json!({ *k: ["x"] }))).collect();
        let eight = Value::Array(arr[..8].to_vec());
        let nine = Value::Array(arr.clone());
        assert_eq!(filter_lookup_plan(eight.clone())["fallback"], json!(false));
        assert_eq!(assert_parity(&eight, &json!({"h": "x"})), 7);
        assert_eq!(filter_lookup_plan(nine.clone())["fallback"], json!(true));
        assert_eq!(filter_lookup_plan(nine.clone())["shapes"], json!([]));
        assert_eq!(resolve_v3(&nine, &json!({"a": "x"})), V3::Fallback);
        assert_eq!(assert_parity(&nine, &json!({"i": "x", "a": "x"})), 0);
    }

    #[test]
    fn oversized_filter_falls_back() {
        let values: Vec<String> = (0..17).map(|i| i.to_string()).collect();
        // 17 x 16 = 272 combinations > 256.
        let arr = json!([f("big", json!({"a": values, "b": values[..16]}))]);
        assert_eq!(filter_lookup_plan(arr.clone())["fallback"], json!(true));
        assert_eq!(filter_lookup_expand(arr.clone()), json!([]));
        assert_eq!(assert_parity(&arr, &json!({"a": "16", "b": "0"})), 0);
        // 16 x 16 = 256 is still expanded.
        let arr = json!([f("ok", json!({"a": values[..16], "b": values[..16]}))]);
        assert_eq!(filter_lookup_plan(arr.clone())["fallback"], json!(false));
        assert_eq!(assert_parity(&arr, &json!({"a": "15", "b": "0"})), 0);
    }

    #[test]
    fn wide_charge_is_one_shape_one_lookup() {
        // The AI-company shape at the size that motivated this change.
        let mut arr = Vec::new();
        for i in 0..1000 {
            let m = format!("model_{i:04}");
            for t in ["input", "output", "cached_input"] {
                arr.push(f(&format!("{m}-{t}"), json!({"model": [m], "token_type": [t]})));
            }
        }
        let arr = Value::Array(arr);
        assert_eq!(filter_lookup_plan(arr.clone())["shapes"], json!([["model", "token_type"]]));
        assert_eq!(assert_parity(&arr, &json!({"model": "model_0999", "token_type": "cached_input"})), 2999);
        assert_eq!(assert_parity(&arr, &json!({"model": "model_0000", "token_type": "input"})), 0);
        assert_eq!(assert_parity(&arr, &json!({"model": "unknown", "token_type": "input"})), -1);
    }

    // ---- randomized parity against the API reference ----

    struct Lcg(u64);
    impl Lcg {
        fn next(&mut self, n: u64) -> u64 {
            self.0 = self.0.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
            (self.0 >> 33) % n
        }
    }

    #[test]
    fn randomized_parity() {
        let keys = ["a", "b", "c", "d", ""];
        let values = ["x", "y", "z", "1", "2.5", "true", ""];
        let stamps = ["2026-09-01 10:00:00", "2026-09-01 10:00:00.5", "2026-09-02 09:00:00"];
        let mut rng = Lcg(42);
        let mut fallbacks = 0;
        for _ in 0..50_000 {
            let nfilters = 1 + rng.next(10);
            let mut arr = Vec::new();
            for i in 0..nfilters {
                // Shapes flat_filters produces: a valueless filter, or keys
                // with value lists (possibly empty, rarely non-string).
                let filters = if rng.next(10) == 0 {
                    json!({"": null})
                } else {
                    let mut m = serde_json::Map::new();
                    for _ in 0..1 + rng.next(3) {
                        let k = keys[rng.next(keys.len() as u64) as usize];
                        let vals: Vec<Value> = (0..rng.next(4))
                            .map(|_| match rng.next(10) {
                                0 => json!(1),
                                _ => json!(values[rng.next(values.len() as u64) as usize]),
                            })
                            .collect();
                        m.insert(k.to_string(), Value::Array(vals));
                    }
                    Value::Object(m)
                };
                let stamp = stamps[rng.next(stamps.len() as u64) as usize];
                arr.push(f_at(&format!("cf{}", rng.next(1000)), stamp, filters));
            }
            let mut props = serde_json::Map::new();
            for k in keys {
                let v = match rng.next(8) {
                    0 => continue,
                    1 => Value::Null,
                    2 => json!(1),
                    3 => json!(2.5),
                    4 => json!(true),
                    _ => json!(values[rng.next(values.len() as u64) as usize]),
                };
                props.insert(k.to_string(), v);
            }
            let arr = Value::Array(arr);
            if resolve_v3(&arr, &Value::Object(props.clone())) == V3::Fallback {
                fallbacks += 1;
            }
            assert_parity(&arr, &Value::Object(props));
        }
        // Up to 10 filters over 5 keys: a few charges exceed 8 shapes, so both
        // paths get exercised.
        assert!(fallbacks > 0 && fallbacks < 5_000, "fallbacks: {fallbacks}");
    }
}
