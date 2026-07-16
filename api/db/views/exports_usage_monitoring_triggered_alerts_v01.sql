SELECT
  ta.id AS lago_id,
  ta.organization_id,
  ta.usage_monitoring_alert_id AS lago_alert_id,
  ta.subscription_id AS lago_subscription_id,
  ta.wallet_id AS lago_wallet_id,
  ta.current_value,
  ta.previous_value,
  ta.crossed_thresholds,
  ta.triggered_at,
  ta.created_at,
  ta.updated_at
FROM usage_monitoring_triggered_alerts AS ta;
