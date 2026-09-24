// Same layout rule as ../../udf/src/lib.rs: the UDF bodies are plain
// top-level items so gen_sql.sh can paste each file verbatim into a
// CREATE FUNCTION body (which must START with the `fn` named like the SQL
// function). Shared helpers live in flv3_common.rs; the event side also
// needs the production json_value_text rule.
include!("filter_lookup_plan.rs");
include!("filter_lookup_expand.rs");
include!("filter_lookup_event_keys.rs");
include!("flv3_common.rs");
include!("../../../udf/src/json_text.rs");

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::{json, Value};
    use std::collections::HashMap;

    // The production UDF, the reference v3 must agree with.
    include!("../../../udf/src/matching_filter.rs");

    // The SQL rank (../sql/02_lookup.sql): more keys first, then the lower
    // position. Positions are 0-based and < RANK_BASE.
    const RANK_BASE: i64 = 1_000_000_000;
    fn rank(key_count: i64, pos: i64) -> i64 {
        key_count * RANK_BASE + (RANK_BASE - 1 - pos)
    }
    fn rank_position(rank: i64) -> i64 {
        RANK_BASE - 1 - rank % RANK_BASE
    }

    #[derive(Debug, PartialEq)]
    enum V3 {
        Fallback,
        // Winner position in filters_agg, -1 for the default bucket.
        Position(i64),
    }

    // The whole v3 pipeline in memory: plan + expand + dedup to the best rank
    // per lookup key (filter_lookup), then the event keys, one lookup per
    // slot, GREATEST over the slots.
    fn resolve_v3(filters_agg: &Value, properties: &Value) -> V3 {
        let plan = filter_lookup_plan(filters_agg.clone());
        if plan["fallback"] == json!(true) {
            return V3::Fallback;
        }
        let mut lookup: HashMap<String, i64> = HashMap::new();
        for (pos, f) in filters_agg.as_array().into_iter().flatten().enumerate() {
            if let Some(x) = filter_lookup_expand(f["filters"].clone()) {
                let r = rank(x["key_count"].as_i64().unwrap(), pos as i64);
                for k in x["lookup_keys"].as_array().unwrap() {
                    let e = lookup.entry(k.as_str().unwrap().to_string()).or_insert(r);
                    *e = (*e).max(r);
                }
            }
        }
        let keys = filter_lookup_event_keys(plan["shapes"].clone(), properties.clone());
        assert!(keys.len() <= FLV3_SHAPE_SLOTS);
        let best = keys.iter().filter(|k| !k.is_empty()).filter_map(|k| lookup.get(k)).max();
        V3::Position(best.map_or(-1, |r| rank_position(*r)))
    }

    // Runs both paths and asserts they pick the same element (or both the
    // default bucket). Returns the v3 position.
    fn assert_parity(filters_agg: &Value, properties: &Value) -> i64 {
        let expected = matching_filter(filters_agg.clone(), properties.clone()).expect("non-empty array");
        let arr = filters_agg.as_array().unwrap();
        match resolve_v3(filters_agg, properties) {
            V3::Position(-1) => {
                assert_eq!(expected, to_default_filter(&arr[0]), "v3 picked default, reference picked {expected}");
                -1
            }
            V3::Position(p) => {
                assert_eq!(expected, arr[p as usize], "v3 picked position {p}, reference picked {expected}");
                p
            }
            V3::Fallback => panic!("unexpected fallback"),
        }
    }

    fn f(id: &str, filters: Value) -> Value {
        json!({
            "charge_filter_id": id,
            "charge_filter_updated_at": "2026-08-28 10:00:00",
            "filters": filters,
            "pricing_group_keys": ["region"]
        })
    }

    // ---- the production matching_filter cases ----

    #[test]
    fn single_empty_filter_is_default() {
        assert_eq!(assert_parity(&json!([f("cf1", json!({}))]), &json!({})), -1);
    }

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
    fn equal_specificity_keeps_first() {
        // Same shape, overlapping values: the lookup row keeps the lower position.
        let arr = json!([f("cf1", json!({"scheme": ["mastercard"]})), f("cf2", json!({"scheme": ["mastercard", "visa"]}))]);
        assert_eq!(assert_parity(&arr, &json!({"scheme": "mastercard"})), 0);
        assert_eq!(assert_parity(&arr, &json!({"scheme": "visa"})), 1);
        // Different shapes, same key count: resolved across slots by rank.
        let arr = json!([f("cf1", json!({"b": ["x"]})), f("cf2", json!({"a": ["x"]}))]);
        assert_eq!(assert_parity(&arr, &json!({"a": "x", "b": "x"})), 0);
    }

    #[test]
    fn missing_or_null_property_does_not_match() {
        let arr = json!([f("cf1", json!({"scheme": ["visa"], "country": ["us"]}))]);
        assert_eq!(assert_parity(&arr, &json!({"scheme": "visa"})), -1);
        assert_eq!(assert_parity(&arr, &json!({"scheme": "visa", "country": null})), -1);
    }

    #[test]
    fn valueless_filter_never_matches() {
        let arr = json!([f("cf1", json!({"": null})), f("cf2", json!({"k": ["v"]}))]);
        assert_eq!(assert_parity(&arr, &json!({"": "x"})), -1);
        assert_eq!(assert_parity(&arr, &json!({"": "x", "k": "v"})), 1);
    }

    #[test]
    fn filterless_charge_null_filters() {
        let arr = json!([{
            "charge_filter_id": null,
            "charge_filter_updated_at": null,
            "filters": null,
            "pricing_group_keys": null
        }]);
        assert_eq!(assert_parity(&arr, &json!({"scheme": "visa"})), -1);
        assert_eq!(filter_lookup_plan(arr), json!({"fallback": false, "shape_count": 0, "shapes": []}));
    }

    #[test]
    fn numeric_and_boolean_properties_match_by_json_text() {
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
    fn non_string_allowed_values_and_empty_lists_never_match() {
        let arr = json!([f("cf1", json!({"k": [12, null, "12"]})), f("cf2", json!({"j": [true]})), f("cf3", json!({"e": []}))]);
        assert_eq!(assert_parity(&arr, &json!({"k": 12})), 0);
        assert_eq!(assert_parity(&arr, &json!({"j": true})), -1);
        assert_eq!(assert_parity(&arr, &json!({"e": ""})), -1);
        // Only cf1 is selectable, so only its shape takes a slot.
        assert_eq!(filter_lookup_plan(arr)["shapes"], json!([["k"]]));
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

    // ---- the lookup encoding and the fallback rules ----

    #[test]
    fn lookup_key_format_is_pinned() {
        let x = filter_lookup_expand(json!({"model": ["b", "a", "a"], "t": ["in"]})).unwrap();
        assert_eq!(x, json!({"key_count": 2, "lookup_keys": ["5:model1:a1:t2:in", "5:model1:b1:t2:in"]}));
        let keys = filter_lookup_event_keys(json!([["model", "t"], ["t"]]), json!({"t": "in", "model": "a"}));
        assert_eq!(keys, vec!["5:model1:a1:t2:in".to_string(), "1:t2:in".to_string()]);
        assert_eq!(filter_lookup_event_keys(json!([["model", "t"]]), json!({"t": "in"})), vec![String::new()]);
    }

    #[test]
    fn shapes_are_canonical() {
        let arr = json!([
            f("a", json!({"t": ["x"]})),
            f("b", json!({"t": ["y"], "model": ["m"]})),
            f("c", json!({"model": ["n"], "t": ["z"]})),
            f("d", json!({"a": ["x"]}))
        ]);
        assert_eq!(
            filter_lookup_plan(arr),
            json!({"fallback": false, "shape_count": 3, "shapes": [["model", "t"], ["a"], ["t"]]})
        );
    }

    #[test]
    fn more_shapes_than_slots_falls_back() {
        let keys = ["a", "b", "c", "d", "e", "f", "g", "h", "i"];
        let arr: Vec<Value> = keys.iter().map(|k| f(k, json!({ *k: ["x"] }))).collect();
        let eight = Value::Array(arr[..8].to_vec());
        let nine = Value::Array(arr.clone());
        assert_eq!(filter_lookup_plan(eight.clone())["fallback"], json!(false));
        assert_eq!(assert_parity(&eight, &json!({"h": "x"})), 7);
        assert_eq!(filter_lookup_plan(nine.clone()), json!({"fallback": true, "shape_count": 9, "shapes": []}));
        assert_eq!(resolve_v3(&nine, &json!({"a": "x"})), V3::Fallback);
    }

    #[test]
    fn oversized_filter_falls_back() {
        let values: Vec<String> = (0..17).map(|i| i.to_string()).collect();
        // 17 x 16 = 272 combinations > 256.
        let arr = json!([f("big", json!({"a": values, "b": values[..16]}))]);
        assert_eq!(filter_lookup_plan(arr.clone())["fallback"], json!(true));
        assert_eq!(filter_lookup_expand(arr[0]["filters"].clone()), None);
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

    // ---- randomized parity against the reference ----

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
        let mut rng = Lcg(42);
        for _ in 0..50_000 {
            let nfilters = 1 + rng.next(8);
            let mut arr = Vec::new();
            for i in 0..nfilters {
                let filters = match rng.next(10) {
                    0 => Value::Null,
                    1 => json!({"": null}),
                    _ => {
                        let mut m = serde_json::Map::new();
                        for _ in 0..rng.next(4) {
                            let k = keys[rng.next(keys.len() as u64) as usize];
                            let vals: Vec<Value> = (0..rng.next(4))
                                .map(|_| match rng.next(10) {
                                    0 => json!(1),
                                    _ => json!(values[rng.next(values.len() as u64) as usize]),
                                })
                                .collect();
                            m.insert(k.to_string(), if rng.next(12) == 0 { Value::Null } else { Value::Array(vals) });
                        }
                        Value::Object(m)
                    }
                };
                arr.push(f(&format!("cf{i}"), filters));
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
            assert_parity(&Value::Array(arr), &Value::Object(props));
        }
    }
}
