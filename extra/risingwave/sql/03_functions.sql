-- Embedded JavaScript UDFs replicating the events-processor's Go logic.
--
-- filter_match_score mirrors models.FlatFilter.IsMatchingEvent + the
-- best-match selection in models.MatchingFilter:
--   returns -1  -> the filter does not match the event
--   returns  0  -> row has no filters (charge default bucket)
--   returns  N  -> filter matches on N keys (higher = more specific = better)
CREATE FUNCTION IF NOT EXISTS filter_match_score(filters JSONB, properties JSONB) RETURNS INT
LANGUAGE javascript AS $$
    if (filters === null || filters === undefined) return 0;
    const props = properties ?? {};
    const keys = Object.keys(filters);
    if (keys.length === 0) return 0;
    for (const key of keys) {
        const value = props[key];
        if (value === null || value === undefined) return -1;
        const allowed = filters[key];
        if (!Array.isArray(allowed)) return -1;
        if (!allowed.includes(String(value))) return -1;
    }
    return keys.length;
$$;

-- extract_grouped_by mirrors enrichWithPricingGroupKeys: builds the
-- `grouped_by` map from the filter's pricing_group_keys plus the
-- target_wallet_code special key.
CREATE FUNCTION IF NOT EXISTS extract_grouped_by(pricing_group_keys JSONB, properties JSONB, accepts_target_wallet BOOLEAN) RETURNS JSONB
LANGUAGE javascript AS $$
    const out = {};
    const keys = Array.isArray(pricing_group_keys) ? pricing_group_keys : [];
    const props = properties ?? {};
    for (const key of keys) {
        const value = props[key];
        out[key] = (value === null || value === undefined) ? "" : String(value);
    }
    if (accepts_target_wallet === true) {
        const wallet = props["target_wallet_code"];
        if (wallet !== null && wallet !== undefined) {
            out["target_wallet_code"] = String(wallet);
        }
    }
    return out;
$$;
