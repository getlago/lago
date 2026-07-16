CREATE MATERIALIZED VIEW events_dead_letter_mv TO events_dead_letter
(
    `organization_id` String,
    `external_subscription_id` String,
    `code` String,
    `transaction_id` String,
    `timestamp` DateTime,
    `ingested_at` DateTime,
    `failed_at` DateTime,
    `event` JSON,
    `initial_error_message` String,
    `error_code` String,
    `error_message` String
)
AS SELECT
  event.organization_id AS organization_id,
  event.external_subscription_id AS external_subscription_id,
  event.code AS code,
  event.transaction_id AS transaction_id,
  coalesce(
    toDateTime64OrNull(toString(event.timestamp), 3),
    toDateTime64(toFloat64OrNull(event.timestamp), 3),
    toDateTime64(event.ingested_at, 3)
  ) AS timestamp,
  toDateTime64(event.ingested_at, 3) AS ingested_at,
  failed_at,
  event,
  error_code,
  error_message,
  initial_error_message
FROM events_dead_letter_queue
