-- GATE 1 smoke: all six dimension tables replicating concurrently, each on
-- its own slot, with Postgres on REPLICA IDENTITY DEFAULT.
--
-- What to look for is not "rows appeared" but: the snapshot row counts match
-- `count(*)`, the changelog keeps flowing afterwards, and an UPDATE produces
-- a -U/+U pair with a correct before-image rather than crashing the job.
CREATE TABLE IF NOT EXISTS cdc_counts (
    src   STRING,
    id    STRING,
    org   STRING
) WITH ('connector' = 'print', 'print-identifier' = 'CDC');

INSERT INTO cdc_counts SELECT 'billable_metrics', id, organization_id FROM billable_metrics;
INSERT INTO cdc_counts SELECT 'subscriptions', id, organization_id FROM subscriptions;
INSERT INTO cdc_counts SELECT 'charges', id, organization_id FROM charges;
INSERT INTO cdc_counts SELECT 'charge_filters', id, organization_id FROM charge_filters;
INSERT INTO cdc_counts SELECT 'charge_filter_values', id, organization_id FROM charge_filter_values;
INSERT INTO cdc_counts SELECT 'billable_metric_filters', id, organization_id FROM billable_metric_filters;
