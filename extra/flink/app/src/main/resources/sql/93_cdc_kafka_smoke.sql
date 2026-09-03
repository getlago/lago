-- Proves the one-slot dimension path end to end: Debezium topic ->
-- upsert-kafka -> correct Flink changelog, with Postgres on
-- REPLICA IDENTITY DEFAULT.
CREATE TABLE IF NOT EXISTS cdck_bm_print (
    id               STRING,
    organization_id  STRING,
    code             STRING,
    aggregation_type INT
) WITH ('connector' = 'print', 'print-identifier' = 'CDCK_BM');

INSERT INTO cdck_bm_print
SELECT id, organization_id, code, aggregation_type FROM billable_metrics_k;
