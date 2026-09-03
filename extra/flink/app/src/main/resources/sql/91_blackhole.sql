-- Throughput harness sink. Discards every row, so a run measures the
-- pipeline's compute cost with the sink removed from the equation — the
-- same isolation the RisingWave investigation reached for when it needed to
-- tell "the stage is slow" apart from "the sink is slow".
--
-- Always take a blackhole number BEFORE a ClickHouse number. A ceiling that
-- moves when the sink changes is a sink ceiling.
CREATE TABLE IF NOT EXISTS blackhole_out (
    organization_id          STRING,
    code                     STRING,
    transaction_id           STRING,
    external_subscription_id STRING,
    kafka_timestamp          TIMESTAMP_LTZ(3)
) WITH (
    'connector' = 'blackhole'
);

INSERT INTO blackhole_out
SELECT
    organization_id,
    code,
    transaction_id,
    external_subscription_id,
    kafka_timestamp
FROM events_raw;
