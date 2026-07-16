SELECT
  ev.id AS lago_id,
  ev.organization_id,
  ev.entitlement_entitlement_id AS lago_entitlement_entitlement_id,
  ev.entitlement_privilege_id AS lago_entitlement_privilege_id,
  ev.value,
  ev.deleted_at,
  ev.created_at,
  ev.updated_at
FROM entitlement_entitlement_values AS ev;
