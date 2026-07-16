SELECT
    organization_id,
    plan_id AS lago_plan_id,
    id AS lago_id,
    amount_cents,
    recurring,
    threshold_display_name,
    created_at,
    updated_at
    deleted_at
FROM usage_thresholds AS ut;
