// The UDF bodies are plain top-level items (no `use`, no modules) because
// RisingWave's inline Rust UDF wrapper requires each CREATE FUNCTION body to
// START with the `fn` named like the SQL function; helpers follow it in the
// same body. gen_sql.sh assembles these files verbatim into
// ../sql/03_functions.sql — this crate exists so the exact same code is unit
// tested against the Go events-processor semantics (models/flat_filters.go,
// models/subscriptions.go, enrichment_service.go).
include!("matching_filter.rs");
include!("pick_subscription.rs");
include!("extract_grouped_by.rs");
include!("json_text.rs");

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::{json, Value};

    // ---- json_value_text: the ONE string-conversion rule, pinned ----
    // Deliberately plain JSON text (Jeremy's decision, 2026-08-28), NOT the
    // Go processor's %v float formatting. These tests exist so the semantics
    // stay a decision, not a library accident.

    #[test]
    fn json_text_semantics_are_pinned() {
        assert_eq!(json_value_text(&json!("visa")), "visa"); // unquoted
        assert_eq!(json_value_text(&json!(true)), "true");
        assert_eq!(json_value_text(&json!(false)), "false");
        assert_eq!(json_value_text(&json!(12)), "12");
        assert_eq!(json_value_text(&json!(12.5)), "12.5");
        assert_eq!(json_value_text(&json!(1000000)), "1000000"); // Go says "1e+06"
        // Known divergences from the Go path, accepted:
        assert_eq!(json_value_text(&json!(0.0000001)), "1e-7"); // Go: "1e-07"
        // Compound values render as compact JSON, not Go's map[a:x] form.
        assert_eq!(json_value_text(&json!(["a", 1])), "[\"a\",1]");
        assert_eq!(json_value_text(&json!({"a": "x"})), "{\"a\":\"x\"}");
    }

    // ---- matching_filter: mirrors TestMatchingFilter (flat_filters_test.go) ----

    fn f(id: &str, filters: Value) -> Value {
        json!({
            "charge_filter_id": id,
            "charge_filter_updated_at": "2026-08-28 10:00:00",
            "filters": filters,
            "pricing_group_keys": ["region"]
        })
    }

    #[test]
    fn default_charge_with_single_empty_filter() {
        // Go: Filters = &FlatFilterValues{} -> HasFilters false -> default
        let res = matching_filter(json!([f("cf1", json!({}))]), json!({})).unwrap();
        assert_eq!(res.get("charge_filter_id"), None);
        assert_eq!(res.get("filters"), None);
        assert_eq!(res["pricing_group_keys"], json!(["region"]));
    }

    #[test]
    fn default_charge_with_single_non_matching_filter() {
        let res = matching_filter(
            json!([f("cf1", json!({"scheme": ["mastercard", "visa"]}))]),
            json!({"scheme": "maestro"}),
        )
        .unwrap();
        assert_eq!(res.get("charge_filter_id"), None);
        assert_eq!(res.get("filters"), None);
    }

    #[test]
    fn single_matching_filter() {
        let cand = f("cf1", json!({"scheme": ["mastercard", "visa"]}));
        let res = matching_filter(json!([cand.clone()]), json!({"scheme": "visa"})).unwrap();
        assert_eq!(res, cand);
    }

    #[test]
    fn default_charge_when_no_matching_among_multiple() {
        let res = matching_filter(
            json!([
                f("cf1", json!({"scheme": ["visa"]})),
                f("cf2", json!({"scheme": ["mastercard"]}))
            ]),
            json!({"scheme": "maestro"}),
        )
        .unwrap();
        assert_eq!(res.get("charge_filter_id"), None);
        assert_eq!(res["pricing_group_keys"], json!(["region"]));
    }

    #[test]
    fn returns_the_matching_filter_among_multiple() {
        let cand2 = f("cf2", json!({"scheme": ["mastercard"]}));
        let res = matching_filter(
            json!([f("cf1", json!({"scheme": ["visa"]})), cand2.clone()]),
            json!({"scheme": "mastercard"}),
        )
        .unwrap();
        assert_eq!(res, cand2);
    }

    #[test]
    fn best_matching_filter_wins_by_key_count() {
        let cand2 = f(
            "cf2",
            json!({"scheme": ["mastercard"], "method": ["debit", "credit"]}),
        );
        let res = matching_filter(
            json!([f("cf1", json!({"scheme": ["mastercard"]})), cand2.clone()]),
            json!({"scheme": "mastercard", "method": "debit"}),
        )
        .unwrap();
        assert_eq!(res, cand2);
    }

    #[test]
    fn equal_specificity_keeps_first_candidate() {
        // Go replaces only on strictly-greater key count.
        let cand1 = f("cf1", json!({"scheme": ["mastercard"]}));
        let res = matching_filter(
            json!([cand1.clone(), f("cf2", json!({"scheme": ["mastercard", "visa"]}))]),
            json!({"scheme": "mastercard"}),
        )
        .unwrap();
        assert_eq!(res, cand1);
    }

    #[test]
    fn missing_property_key_does_not_match() {
        // Go: event.Properties[key] == nil -> no match (TestIsMatchingEvent)
        let res = matching_filter(
            json!([f("cf1", json!({"scheme": ["visa"], "country": ["us"]}))]),
            json!({"scheme": "visa"}),
        )
        .unwrap();
        assert_eq!(res.get("charge_filter_id"), None);
    }

    #[test]
    fn json_null_property_does_not_match() {
        let res = matching_filter(
            json!([f("cf1", json!({"scheme": ["visa"]}))]),
            json!({"scheme": null}),
        )
        .unwrap();
        assert_eq!(res.get("charge_filter_id"), None);
    }

    #[test]
    fn valueless_filter_row_never_matches() {
        // {"": null} is the flat_filters encoding of a charge filter with no
        // values; HasFilters is true, matching is false.
        let res = matching_filter(json!([f("cf1", json!({"": null}))]), json!({"": "x"})).unwrap();
        assert_eq!(res.get("charge_filter_id"), None);
    }

    #[test]
    fn charge_without_filters_null_filters_field() {
        // A filterless charge has one row with filters = null (SQL NULL).
        let cand = json!({
            "charge_filter_id": null,
            "charge_filter_updated_at": null,
            "filters": null,
            "pricing_group_keys": null
        });
        let res = matching_filter(json!([cand]), json!({"scheme": "visa"})).unwrap();
        assert_eq!(res.get("charge_filter_id"), None);
        assert_eq!(res.get("pricing_group_keys"), None); // null pgk omitted
    }

    #[test]
    fn numeric_property_matches_by_json_text() {
        let cand = f("cf1", json!({"tier": ["12"]}));
        let res = matching_filter(json!([cand.clone()]), json!({"tier": 12})).unwrap();
        assert_eq!(res, cand);
        let res = matching_filter(
            json!([f("cf1", json!({"tier": ["12.5"]}))]),
            json!({"tier": 12.5}),
        )
        .unwrap();
        assert_eq!(res["charge_filter_id"], json!("cf1"));
    }

    #[test]
    fn empty_or_missing_array_returns_none() {
        assert!(matching_filter(json!([]), json!({})).is_none());
        assert!(matching_filter(Value::Null, json!({})).is_none());
    }

    // ---- pick_subscription: mirrors FetchSubscription semantics ----

    fn sub(id: &str, started_ms: Option<i64>, terminated_ms: Option<i64>) -> Value {
        json!({
            "id": id,
            "customer_id": format!("cust_{id}"),
            "plan_id": format!("plan_{id}"),
            "started_at_ms": started_ms,
            "terminated_at_ms": terminated_ms
        })
    }

    #[test]
    fn picks_active_subscription_in_window() {
        let subs = json!([sub("a", Some(1_000_000), None)]);
        let res = pick_subscription(subs, 2_000.0).unwrap();
        assert_eq!(res["id"], json!("a"));
    }

    #[test]
    fn excludes_not_yet_started_and_terminated_before() {
        let subs = json!([
            sub("future", Some(3_000_000), None),
            sub("ended", Some(1_000_000), Some(1_500_000))
        ]);
        assert!(pick_subscription(subs, 2_000.0).is_none());
    }

    #[test]
    fn terminated_at_boundary_is_inclusive() {
        // Go: terminated_at >= ts
        let subs = json!([sub("a", Some(1_000_000), Some(2_000_000))]);
        assert!(pick_subscription(subs, 2_000.0).is_some());
        // started_at <= ts
        let subs = json!([sub("a", Some(2_000_000), None)]);
        assert!(pick_subscription(subs, 2_000.0).is_some());
    }

    #[test]
    fn null_started_at_never_qualifies() {
        let subs = json!([sub("a", None, None)]);
        assert!(pick_subscription(subs, 2_000.0).is_none());
    }

    #[test]
    fn non_terminated_wins_over_terminated() {
        // ORDER BY terminated_at DESC NULLS FIRST
        let subs = json!([
            sub("terminated", Some(1_000_000), Some(3_000_000)),
            sub("active", Some(1_500_000), None)
        ]);
        let res = pick_subscription(subs, 2_000.0).unwrap();
        assert_eq!(res["id"], json!("active"));
    }

    #[test]
    fn later_terminated_wins() {
        let subs = json!([
            sub("early", Some(1_000_000), Some(2_500_000)),
            sub("late", Some(1_000_000), Some(3_000_000))
        ]);
        let res = pick_subscription(subs, 2_000.0).unwrap();
        assert_eq!(res["id"], json!("late"));
    }

    #[test]
    fn later_started_wins_within_equal_termination() {
        let subs = json!([
            sub("old", Some(1_000_000), None),
            sub("new", Some(1_500_000), None)
        ]);
        let res = pick_subscription(subs, 2_000.0).unwrap();
        assert_eq!(res["id"], json!("new"));
    }

    #[test]
    fn full_tie_breaks_on_id_asc() {
        let subs = json!([
            sub("b", Some(1_000_000), None),
            sub("a", Some(1_000_000), None)
        ]);
        let res = pick_subscription(subs, 2_000.0).unwrap();
        assert_eq!(res["id"], json!("a"));
    }

    #[test]
    fn event_timestamp_keeps_sub_millisecond_precision() {
        // Go truncates only the SUBSCRIPTION timestamps to ms (the agg MV
        // does that); the event timestamp is compared untruncated.
        let subs = json!([sub("a", Some(2_000_000), None)]);
        // event at 1999.9995s < started 2000.000s -> no match
        assert!(pick_subscription(subs.clone(), 1_999.9995).is_none());
        assert!(pick_subscription(subs, 2_000.0004).is_some());
    }

    // ---- extract_grouped_by: mirrors enrichWithPricingGroupKeys ----

    #[test]
    fn grouped_by_basics() {
        let res = extract_grouped_by(
            json!(["region", "missing"]),
            json!({"region": "eu", "other": 1}),
            false,
        );
        assert_eq!(res, json!({"region": "eu", "missing": ""}));
    }

    #[test]
    fn grouped_by_formats_values_as_json_text() {
        let res = extract_grouped_by(json!(["n"]), json!({"n": 12.5}), false);
        assert_eq!(res, json!({"n": "12.5"}));
    }

    #[test]
    fn grouped_by_null_property_maps_to_empty_string() {
        let res = extract_grouped_by(json!(["k"]), json!({"k": null}), false);
        assert_eq!(res, json!({"k": ""}));
    }

    #[test]
    fn grouped_by_target_wallet_only_when_present() {
        let res = extract_grouped_by(json!([]), json!({"target_wallet_code": "w1"}), true);
        assert_eq!(res, json!({"target_wallet_code": "w1"}));
        let res = extract_grouped_by(json!([]), json!({"target_wallet_code": null}), true);
        assert_eq!(res, json!({}));
        let res = extract_grouped_by(json!([]), json!({}), true);
        assert_eq!(res, json!({}));
        let res = extract_grouped_by(json!([]), json!({"target_wallet_code": "w1"}), false);
        assert_eq!(res, json!({}));
    }

    #[test]
    fn grouped_by_null_pricing_group_keys_gives_empty_object() {
        let res = extract_grouped_by(Value::Null, json!({"a": 1}), false);
        assert_eq!(res, json!({}));
    }
}
