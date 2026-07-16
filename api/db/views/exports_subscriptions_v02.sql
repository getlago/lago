SELECT
  s.organization_id,
  s.id AS lago_id,
  s.external_id,
  s.customer_id AS lago_customer_id,
  s.name,
  s.plan_id AS lago_plan_id,
  CASE s.status
    WHEN 0 THEN 'pending'
    WHEN 1 THEN 'active'
    WHEN 2 THEN 'terminated'
    WHEN 3 THEN 'canceled'
  END AS status,
  CASE s.billing_time
    WHEN 0 THEN 'calendar'
    WHEN 1 THEN 'anniversary'
  END AS billing_time,
  s.subscription_at,
  s.started_at,
  s.trial_ended_at,
  s.ending_at,
  s.terminated_at,
  s.canceled_at,
  s.created_at,
  s.updated_at,
  to_json (
    ARRAY(
      SELECT
        ns.id
      FROM
        subscriptions AS ns
      WHERE
        ns.previous_subscription_id = s.id
    )
  ) AS lago_next_subscriptions_id,
  s.previous_subscription_id AS lago_previous_subscription_id
FROM
  subscriptions AS s;
