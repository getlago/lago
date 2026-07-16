SELECT
  ee.id AS lago_id,
  ee.organization_id,
  ee.entitlement_feature_id AS lago_entitlement_feature_id,
  ee.plan_id AS lago_plan_id,
  ee.subscription_id AS lago_subscription_id,
  ee.deleted_at,
  ee.created_at,
  ee.updated_at
FROM entitlement_entitlements AS ee;
