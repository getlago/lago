SELECT
  ath.id AS lago_id,
  ath.organization_id,
  ath.usage_monitoring_alert_id AS lago_alert_id,
  ath.value,
  ath.code,
  ath.recurring,
  ath.created_at,
  ath.updated_at
FROM usage_monitoring_alert_thresholds AS ath;
