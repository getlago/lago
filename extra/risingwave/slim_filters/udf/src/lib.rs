// Same layout rule as ../../udf/src/lib.rs: the UDF bodies are plain
// top-level items so gen_sql.sh can paste each file verbatim into a
// CREATE FUNCTION body (which must START with the `fn` named like the SQL
// function). Helpers are prefixed (ep_, mfp_) so they cannot collide with the
// production UDF helpers pulled in below for the parity tests.
include!("encode_filter_payload.rs");
include!("match_filter_position.rs");

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::{json, Value};

    // The production UDFs, the reference the slim path must agree with.
    include!("../../../udf/src/matching_filter.rs");
    include!("../../../udf/src/json_text.rs");

    // Runs both paths and asserts they pick the same element (or both the
    // default bucket). Returns the slim position for extra assertions.
    fn assert_parity(filters: &Value, properties: &Value) -> Option<i32> {
        let expected = matching_filter(filters.clone(), properties.clone());
        let payload = encode_filter_payload(filters.clone());
        let pos = match_filter_position(&payload, properties.clone());
        match (&expected, pos) {
            (None, None) => {}
            (Some(exp), Some(-1)) => {
                let arr = filters.as_array().unwrap();
                assert_eq!(exp, &to_default_filter(&arr[0]), "slim picked default, reference picked {exp}");
            }
            (Some(exp), Some(p)) if p >= 0 => {
                let arr = filters.as_array().unwrap();
                assert_eq!(exp, &arr[p as usize], "slim picked position {p}, reference picked {exp}");
            }
            _ => panic!("reference {expected:?} vs slim {pos:?} (payload {payload:?})"),
        }
        pos
    }

    fn f(id: &str, filters: Value) -> Value {
        json!({
            "charge_filter_id": id,
            "charge_filter_updated_at": "2026-08-28 10:00:00",
            "filters": filters,
            "pricing_group_keys": ["region"]
        })
    }

    // ---- the production matching_filter cases, through both paths ----

    #[test]
    fn single_empty_filter_is_default() {
        assert_eq!(assert_parity(&json!([f("cf1", json!({}))]), &json!({})), Some(-1));
    }

    #[test]
    fn single_non_matching_filter_is_default() {
        let arr = json!([f("cf1", json!({"scheme": ["mastercard", "visa"]}))]);
        assert_eq!(assert_parity(&arr, &json!({"scheme": "maestro"})), Some(-1));
    }

    #[test]
    fn single_matching_filter() {
        let arr = json!([f("cf1", json!({"scheme": ["mastercard", "visa"]}))]);
        assert_eq!(assert_parity(&arr, &json!({"scheme": "visa"})), Some(0));
    }

    #[test]
    fn no_match_among_multiple_is_default() {
        let arr = json!([f("cf1", json!({"scheme": ["visa"]})), f("cf2", json!({"scheme": ["mastercard"]}))]);
        assert_eq!(assert_parity(&arr, &json!({"scheme": "maestro"})), Some(-1));
    }

    #[test]
    fn matching_filter_among_multiple() {
        let arr = json!([f("cf1", json!({"scheme": ["visa"]})), f("cf2", json!({"scheme": ["mastercard"]}))]);
        assert_eq!(assert_parity(&arr, &json!({"scheme": "mastercard"})), Some(1));
    }

    #[test]
    fn most_keys_wins() {
        let arr = json!([
            f("cf1", json!({"scheme": ["mastercard"]})),
            f("cf2", json!({"scheme": ["mastercard"], "method": ["debit", "credit"]}))
        ]);
        assert_eq!(assert_parity(&arr, &json!({"scheme": "mastercard", "method": "debit"})), Some(1));
    }

    #[test]
    fn most_keys_wins_even_when_listed_first() {
        let arr = json!([
            f("cf1", json!({"scheme": ["mastercard"], "method": ["debit"]})),
            f("cf2", json!({"scheme": ["mastercard"]}))
        ]);
        assert_eq!(assert_parity(&arr, &json!({"scheme": "mastercard", "method": "debit"})), Some(0));
    }

    #[test]
    fn equal_specificity_keeps_first() {
        let arr = json!([
            f("cf1", json!({"scheme": ["mastercard"]})),
            f("cf2", json!({"scheme": ["mastercard", "visa"]}))
        ]);
        assert_eq!(assert_parity(&arr, &json!({"scheme": "mastercard"})), Some(0));
    }

    #[test]
    fn missing_property_key_does_not_match() {
        let arr = json!([f("cf1", json!({"scheme": ["visa"], "country": ["us"]}))]);
        assert_eq!(assert_parity(&arr, &json!({"scheme": "visa"})), Some(-1));
    }

    #[test]
    fn json_null_property_does_not_match() {
        let arr = json!([f("cf1", json!({"scheme": ["visa"]}))]);
        assert_eq!(assert_parity(&arr, &json!({"scheme": null})), Some(-1));
    }

    #[test]
    fn valueless_filter_never_matches() {
        let arr = json!([f("cf1", json!({"": null}))]);
        assert_eq!(assert_parity(&arr, &json!({"": "x"})), Some(-1));
    }

    #[test]
    fn valueless_filter_next_to_a_matching_one() {
        let arr = json!([f("cf1", json!({"": null})), f("cf2", json!({"scheme": ["visa"]}))]);
        assert_eq!(assert_parity(&arr, &json!({"": "x", "scheme": "visa"})), Some(1));
    }

    #[test]
    fn filterless_charge_null_filters() {
        let arr = json!([{
            "charge_filter_id": null,
            "charge_filter_updated_at": null,
            "filters": null,
            "pricing_group_keys": null
        }]);
        assert_eq!(assert_parity(&arr, &json!({"scheme": "visa"})), Some(-1));
    }

    #[test]
    fn numeric_and_boolean_properties_match_by_json_text() {
        let arr = json!([f("cf1", json!({"tier": ["12"]})), f("cf2", json!({"tier": ["12.5"]})), f("cf3", json!({"flag": ["true"]}))]);
        assert_eq!(assert_parity(&arr, &json!({"tier": 12})), Some(0));
        assert_eq!(assert_parity(&arr, &json!({"tier": 12.5})), Some(1));
        assert_eq!(assert_parity(&arr, &json!({"flag": true})), Some(2));
        assert_eq!(assert_parity(&arr, &json!({"tier": 1000000})), Some(-1));
    }

    #[test]
    fn non_object_properties_match_nothing() {
        let arr = json!([f("cf1", json!({"scheme": ["visa"]}))]);
        assert_eq!(assert_parity(&arr, &json!(["visa"])), Some(-1));
        assert_eq!(assert_parity(&arr, &json!("visa")), Some(-1));
    }

    #[test]
    fn empty_or_missing_array_returns_none() {
        assert_eq!(assert_parity(&json!([]), &json!({})), None);
        assert_eq!(assert_parity(&Value::Null, &json!({})), None);
    }

    // ---- encoding edge cases ----

    #[test]
    fn separators_and_digits_inside_values_are_safe() {
        // Values that look like the framing itself.
        let tricky = ["3:abc", ";", ":", "12;", "n", "0;", "", "1:x1:y"];
        for (i, v) in tricky.iter().enumerate() {
            let arr = json!([
                f("decoy", json!({"k": ["other"]})),
                f("cf", json!({"k": [v], "3:k": [v]}))
            ]);
            assert_eq!(assert_parity(&arr, &json!({"k": v, "3:k": v})), Some(1), "case {i}: {v:?}");
            assert_eq!(assert_parity(&arr, &json!({"k": v})), Some(-1), "case {i}: {v:?}");
        }
    }

    #[test]
    fn multibyte_utf8() {
        let arr = json!([f("cf1", json!({"région": ["île-de-France", "日本"]}))]);
        assert_eq!(assert_parity(&arr, &json!({"région": "日本"})), Some(0));
        assert_eq!(assert_parity(&arr, &json!({"région": "日"})), Some(-1));
    }

    #[test]
    fn empty_string_value_and_empty_value_list() {
        let arr = json!([f("cf1", json!({"k": [""]})), f("cf2", json!({"j": []}))]);
        assert_eq!(assert_parity(&arr, &json!({"k": ""})), Some(0));
        assert_eq!(assert_parity(&arr, &json!({"j": ""})), Some(-1));
    }

    #[test]
    fn non_string_allowed_values_never_match() {
        let arr = json!([f("cf1", json!({"k": [12, null, "12"]})), f("cf2", json!({"j": [true]}))]);
        assert_eq!(assert_parity(&arr, &json!({"k": 12})), Some(0));
        assert_eq!(assert_parity(&arr, &json!({"j": true})), Some(-1));
    }

    #[test]
    fn malformed_payload_is_null_not_a_panic() {
        for bad in ["x", "5:0;", "3:1;", "9:1;1:k1;1:v", "2:0", "99999999999999999999999:"] {
            assert_eq!(match_filter_position(bad, json!({"k": "v"})), None, "{bad:?}");
        }
    }

    #[test]
    fn payload_format_is_pinned() {
        let arr = json!([
            f("cf1", json!({"k": ["a", "bc"]})),
            f("cf2", json!({"": null})),
            {"filters": null}
        ]);
        assert_eq!(encode_filter_payload(arr), "14:1;1:k2;1:a2:bc5:1;0:n2:0;");
    }

    #[test]
    fn wide_charge_last_filter_and_default() {
        // The AI-company shape at the size that motivated this change.
        let models: Vec<String> = (0..834).map(|i| format!("model_{i:04}")).collect();
        let mut arr = Vec::new();
        for m in &models {
            for t in ["input", "output", "cached_input"] {
                arr.push(f(&format!("{m}-{t}"), json!({"model": [m], "token_type": [t]})));
            }
        }
        let arr = Value::Array(arr);
        assert_eq!(assert_parity(&arr, &json!({"model": "model_0833", "token_type": "cached_input"})), Some(2501));
        assert_eq!(assert_parity(&arr, &json!({"model": "model_0000", "token_type": "input"})), Some(0));
        assert_eq!(assert_parity(&arr, &json!({"model": "unknown", "token_type": "input"})), Some(-1));
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
        for _ in 0..20_000 {
            let nfilters = 1 + rng.next(6);
            let mut arr = Vec::new();
            for i in 0..nfilters {
                let filters = match rng.next(10) {
                    0 => Value::Null,
                    1 => json!({"": null}),
                    _ => {
                        let mut m = serde_json::Map::new();
                        for _ in 0..rng.next(4) {
                            let k = keys[rng.next(keys.len() as u64) as usize];
                            let vals: Vec<Value> = (0..rng.next(3))
                                .map(|_| json!(values[rng.next(values.len() as u64) as usize]))
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
