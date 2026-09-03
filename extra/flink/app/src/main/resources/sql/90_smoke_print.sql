-- GATE 0 smoke test: prove that a Flink 2.3 cluster, a connector built
-- against Flink 2.2, and the Redpanda topic actually work together end to
-- end. Prints to TaskManager stdout (`docker logs` on the taskmanager).
--
-- This exists to answer one question empirically instead of by inference:
-- the newest published flink-connector-kafka is 5.0.0-2.2, and nothing in
-- the release notes promises it runs on 2.3. If this prints rows, it does.
CREATE TABLE IF NOT EXISTS smoke_print (
    organization_id          STRING,
    code                     STRING,
    transaction_id           STRING,
    external_subscription_id STRING,
    `timestamp`              STRING,
    kafka_timestamp          TIMESTAMP_LTZ(3)
) WITH (
    'connector'    = 'print',
    'print-identifier' = 'SMOKE'
);

INSERT INTO smoke_print
SELECT
    organization_id,
    code,
    transaction_id,
    external_subscription_id,
    `timestamp`,
    kafka_timestamp
FROM events_raw;
