SELECT
  im.id AS lago_id,
  im.organization_id,
  im.owner_type,
  im.owner_id AS lago_owner_id,
  im.value,
  im.created_at,
  im.updated_at
FROM item_metadata AS im;
