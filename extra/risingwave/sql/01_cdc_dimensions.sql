-- Dimension tables replicated live from the Lago Postgres database through
-- RisingWave's native Postgres CDC connector (initial snapshot + logical
-- replication). This replaces the events-processor's BadgerDB cache and the
-- Debezium topics.
--
-- Dev credentials match docker-compose.dev.yml defaults (lago / changeme).
CREATE SOURCE IF NOT EXISTS lago_pg WITH (
    connector = 'postgres-cdc',
    hostname = 'db',
    port = '5432',
    username = 'lago',
    password = 'changeme',
    database.name = 'lago',
    schema.name = 'public',
    slot.name = 'risingwave_dev',
    publication.name = 'rw_publication'
);

CREATE TABLE IF NOT EXISTS billable_metrics (
    id VARCHAR PRIMARY KEY,
    organization_id VARCHAR,
    code VARCHAR,
    aggregation_type INT,
    recurring BOOLEAN,
    field_name VARCHAR,
    expression VARCHAR,
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    deleted_at TIMESTAMP
) FROM lago_pg TABLE 'public.billable_metrics';

CREATE TABLE IF NOT EXISTS subscriptions (
    id VARCHAR PRIMARY KEY,
    organization_id VARCHAR,
    customer_id VARCHAR,
    external_id VARCHAR,
    plan_id VARCHAR,
    status INT,
    started_at TIMESTAMP,
    terminated_at TIMESTAMP,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
) FROM lago_pg TABLE 'public.subscriptions';

CREATE TABLE IF NOT EXISTS charges (
    id VARCHAR PRIMARY KEY,
    organization_id VARCHAR,
    plan_id VARCHAR,
    billable_metric_id VARCHAR,
    code VARCHAR,
    properties JSONB,
    pay_in_advance BOOLEAN,
    accepts_target_wallet BOOLEAN,
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    deleted_at TIMESTAMP
) FROM lago_pg TABLE 'public.charges';

CREATE TABLE IF NOT EXISTS charge_filters (
    id VARCHAR PRIMARY KEY,
    organization_id VARCHAR,
    charge_id VARCHAR,
    properties JSONB,
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    deleted_at TIMESTAMP
) FROM lago_pg TABLE 'public.charge_filters';

CREATE TABLE IF NOT EXISTS charge_filter_values (
    id VARCHAR PRIMARY KEY,
    organization_id VARCHAR,
    charge_filter_id VARCHAR,
    billable_metric_filter_id VARCHAR,
    "values" VARCHAR[],
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    deleted_at TIMESTAMP
) FROM lago_pg TABLE 'public.charge_filter_values';

CREATE TABLE IF NOT EXISTS billable_metric_filters (
    id VARCHAR PRIMARY KEY,
    organization_id VARCHAR,
    billable_metric_id VARCHAR,
    key VARCHAR,
    "values" VARCHAR[],
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    deleted_at TIMESTAMP
) FROM lago_pg TABLE 'public.billable_metric_filters';

-- Indexes backing the temporal-join lookups in the enrichment view.
CREATE INDEX IF NOT EXISTS idx_billable_metrics_org_code
    ON billable_metrics (organization_id, code);
CREATE INDEX IF NOT EXISTS idx_subscriptions_org_external_id
    ON subscriptions (organization_id, external_id);

-- Billing periods maintained by Rails (Clock::RefreshSubscriptionBillingPeriodsJob,
-- current + next period per active subscription). Date logic stays in Ruby.
-- NOTE: on a fresh Postgres the publication is created by RisingWave for the
-- tables above; when adding this table to an existing setup run:
--   ALTER PUBLICATION rw_publication ADD TABLE public.subscription_billing_periods;
CREATE TABLE IF NOT EXISTS subscription_billing_periods (
    id VARCHAR PRIMARY KEY,
    organization_id VARCHAR,
    subscription_id VARCHAR,
    charges_from TIMESTAMP,
    charges_to TIMESTAMP,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
) FROM lago_pg TABLE 'public.subscription_billing_periods';

CREATE INDEX IF NOT EXISTS idx_billing_periods_subscription
    ON subscription_billing_periods (subscription_id);
