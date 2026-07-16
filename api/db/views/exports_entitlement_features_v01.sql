SELECT
  ef.id AS lago_id,
  ef.organization_id,
  ef.code,
  ef.name,
  ef.description,
  ef.deleted_at,
  ef.created_at,
  ef.updated_at
FROM entitlement_features AS ef;
