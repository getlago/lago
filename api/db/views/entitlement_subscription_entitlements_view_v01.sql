WITH
  subscription_entitlements AS (
    SELECT
      fe.entitlement_feature_id,
      fe.plan_id,
      fe.subscription_id,
      fev.deleted_at AS deleted_at,
      fev.id,
      fev.entitlement_privilege_id,
      fev.entitlement_entitlement_id,
      fev.value
    FROM
      entitlement_entitlement_values fev
        JOIN entitlement_entitlements fe ON fe.id = fev.entitlement_entitlement_id
    WHERE
      fev.deleted_at IS NULL
  ),
  all_values AS (
    SELECT
      ep.entitlement_feature_id,
      COALESCE(ep.entitlement_privilege_id, es.entitlement_privilege_id) AS entitlement_privilege_id,
      ep.entitlement_entitlement_id AS plan_entitlement_id,
      es.entitlement_entitlement_id AS override_entitlement_id,
      ep.id AS plan_entitlement_values_id,
      es.id AS override_entitlement_values_id,
      ep.value AS plan_value,
      es.value AS override_value
    FROM
      subscription_entitlements ep
        FULL OUTER JOIN subscription_entitlements es ON ep.entitlement_privilege_id = es.entitlement_privilege_id
        AND ep.plan_id IS NOT NULL
        AND es.subscription_id IS NOT NULL
    WHERE
      (
        ep.plan_id IS NOT NULL
          OR es.subscription_id IS NOT NULL
        )
      AND ep.deleted_at IS NULL
      AND es.deleted_at IS NULL
  )
SELECT
  f.id AS entitlement_feature_id,
  f.organization_id AS organization_id,
  f.code AS feature_code,
  f.name AS feature_name,
  f.description AS feature_description,
  f.deleted_at AS feature_deleted_at,
  pri.id AS entitlement_privilege_id,
  pri.code AS privilege_code,
  pri.name AS privilege_name,
  pri.value_type AS privilege_value_type,
  pri.config AS privilege_config,
  pri.deleted_at AS privilege_deleted_at,
  fe.plan_id AS plan_id,
  fe.subscription_id AS subscription_id,
  (sfr.id IS NOT NULL) AS removed,
  av.plan_entitlement_id,
  av.override_entitlement_id,
  av.plan_entitlement_values_id,
  av.override_entitlement_values_id,
  av.plan_value AS privilege_plan_value,
  av.override_value AS privilege_override_value
FROM
  entitlement_entitlements fe
    LEFT JOIN entitlement_subscription_feature_removals sfr ON fe.entitlement_feature_id = sfr.entitlement_feature_id AND sfr.deleted_at IS NULL
    LEFT JOIN all_values av ON COALESCE(av.override_entitlement_id, av.plan_entitlement_id) = fe.id
    LEFT JOIN entitlement_features f ON f.id = fe.entitlement_feature_id
    LEFT JOIN entitlement_privileges pri ON pri.id = av.entitlement_privilege_id;
