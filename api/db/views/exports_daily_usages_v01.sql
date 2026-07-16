SELECT
  du.organization_id,
  du.id AS lago_id,
  du.from_datetime,
  du.to_datetime,
  du.refreshed_at,
  du.usage_date,
  du.usage AS daily_usage,
  du.usage_diff AS daily_usage_diff,
  du.created_at,
  du.updated_at,
  du.customer_id AS lago_customer_id,
  du.subscription_id AS lago_subscription_id,
  du.external_subscription_id
FROM daily_usages AS du;