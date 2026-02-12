# Database Partitioning

## Overview

The `enriched_events` table uses PostgreSQL native range partitioning managed by [pg_partman](https://github.com/pgpartman/pg_partman). Partitions are created monthly based on the `timestamp` column.

### Partition configuration

| Parameter                  | Value        |
|----------------------------|--------------|
| Partition key              | `timestamp`  |
| Interval                   | 1 month      |
| Type                       | range        |
| Pre-creation               | 3 months     |
| Retention                  | 14 months    |
| Retention keeps tables     | yes          |
| Infinite time partitions   | yes          |

This configuration lives in `partman.part_config`.

## Checking extension availability

Before any setup, verify that `pg_partman` is available on your PostgreSQL server:

```sql
SELECT * FROM pg_available_extensions WHERE name = 'pg_partman';
```

If the query returns no rows, the extension is not installed on the server and you need to install it before proceeding. All Lago migrations that depend on pg_partman check this and skip gracefully when the extension is absent.

Once installed as an extension, verify it is enabled in your database:

```sql
SELECT * FROM pg_extension WHERE extname = 'pg_partman';
```

## Retroactive setup (pg_partman installed after initial migrations)

Lago migrations skip partitioning gracefully when pg_partman is not available at migration time. The `enriched_events` table is then created as a regular (non-partitioned) table. If you install pg_partman later, follow the steps below to convert the existing table to a partitioned one and register it with pg_partman.

> All SQL below must be run by a role with ownership on the `enriched_events` table.

### 1. Install the pg_partman extension

```sql
CREATE SCHEMA IF NOT EXISTS partman;
CREATE EXTENSION IF NOT EXISTS pg_partman SCHEMA partman;
```

### 2. Rename the existing table

```sql
ALTER TABLE public.enriched_events RENAME TO enriched_events_old;
```

### 3. Create the partitioned table

```sql
CREATE TABLE public.enriched_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    event_id uuid NOT NULL,
    transaction_id character varying NOT NULL,
    external_subscription_id character varying NOT NULL,
    code character varying NOT NULL,
    "timestamp" timestamp(6) without time zone NOT NULL,
    subscription_id uuid NOT NULL,
    plan_id uuid NOT NULL,
    charge_id uuid NOT NULL,
    charge_filter_id uuid,
    grouped_by jsonb DEFAULT '{}'::jsonb NOT NULL,
    value character varying,
    decimal_value numeric(40,15) DEFAULT 0.0 NOT NULL,
    enriched_at timestamp(6) without time zone NOT NULL,
    PRIMARY KEY (id, "timestamp")
) PARTITION BY RANGE ("timestamp");

CREATE TABLE public.enriched_events_default PARTITION OF public.enriched_events DEFAULT;
```

### 4. Recreate indexes

```sql
CREATE INDEX idx_billing_on_enriched_events
    ON public.enriched_events (organization_id, subscription_id, charge_id, charge_filter_id, "timestamp");

CREATE INDEX idx_lookup_on_enriched_events
    ON public.enriched_events (organization_id, external_subscription_id, code, "timestamp");

CREATE UNIQUE INDEX idx_unique_on_enriched_events
    ON public.enriched_events (organization_id, external_subscription_id, transaction_id, "timestamp", charge_id);

CREATE INDEX index_enriched_events_on_event_id
    ON public.enriched_events (event_id);
```

### 5. Migrate existing data

```sql
INSERT INTO public.enriched_events
SELECT * FROM public.enriched_events_old;
```

> If the table is large, consider batching inserts or running this during a maintenance window.

### 6. Drop the old table

```sql
DROP TABLE public.enriched_events_old;
```

### 7. Register with pg_partman

```sql
SELECT partman.create_parent(
    p_parent_table := 'public.enriched_events',
    p_control := 'timestamp',
    p_interval := '1 month',
    p_type := 'range',
    p_premake := 3,
    p_start_partition := '2024-12-01'
);

UPDATE partman.part_config
SET infinite_time_partitions = true,
    retention = '14 months',
    retention_keep_table = true
WHERE parent_table = 'public.enriched_events';
```

### 8. Run initial maintenance

Trigger a first maintenance run to create the monthly partitions and move data out of the default partition into the correct ones:

```sql
CALL partman.run_maintenance_proc();
```

After this, configure one of the two scheduled maintenance approaches described below.

---

## Partitioning maintenance

pg_partman requires periodic execution of `partman.run_maintenance_proc()` to:

- Create future partitions (based on `p_premake`)
- Drop or detach expired partitions (based on `retention`)

If maintenance does not run, inserts will fall into the `enriched_events_default` default partition, degrading query performance and making future partition creation harder to reconcile.

There are two approaches to schedule this.

---

### Approach 1: pg_partman Background Worker (`pg_partman_bgw`)

This is a built-in background worker shipped with pg_partman. It requires no additional extension but needs PostgreSQL server-level configuration (i.e. access to `postgresql.conf`).

#### 1. Configure `postgresql.conf`

Add `pg_partman_bgw` to `shared_preload_libraries` and set its parameters:

```conf
shared_preload_libraries = 'pg_partman_bgw'

pg_partman_bgw.dbname = lago
pg_partman_bgw.interval = 3600   # seconds (1 hour)
pg_partman_bgw.role = lago
```

- `dbname` — the database(s) to run maintenance on (comma-separated for multiple).
- `interval` — how often to run, in seconds. 3600 = hourly.
- `role` — the PostgreSQL role used to execute maintenance. Must have ownership or sufficient privileges on the partitioned tables and the `partman` schema.

Changes to `shared_preload_libraries` require a full server restart.


#### 2. Verify the worker is running

```sql
SELECT * FROM pg_stat_activity WHERE backend_type = 'pg_partman_bgw';
```

You should see one active row. You can also check the PostgreSQL logs for entries like:

```
LOG:  pg_partman_bgw: running maintenance on database "lago"
```

---

### Approach 2: pg_cron

`pg_partman_bgw` is not provided by some managed PostgresSQL providers, in this case or if you prefer a SQL-level scheduling interface you could rely on [pg_cron](https://github.com/citusdata/pg_cron).

#### 1. Install the pg_cron extension

pg_cron also requires being loaded at server start. In `postgresql.conf`:

```conf
shared_preload_libraries = 'pg_cron'

cron.database_name = 'postgres'
```

Changes to `shared_preload_libraries` require a full server restart.


#### 2. Enable the extension

Open a connection to the `postgres` database

```sql
CREATE EXTENSION IF NOT EXISTS pg_cron;
```

#### 3. Schedule the maintenance job

```sql
SELECT cron.schedule_in_database(
  'partman-maintenance', 
  '@hourly',
  $$CALL partman.run_maintenance_proc()$$,
  'lago'
);
```

#### 4. Verify the job is scheduled

```sql
SELECT jobid, schedule, command, nodename, active
FROM cron.job
WHERE jobname = 'partman-maintenance';
```

#### 5. Check execution history

```sql
SELECT jobid, start_time, end_time, status, return_message
FROM cron.job_run_details
WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'partman-maintenance')
ORDER BY start_time DESC
LIMIT 10;
```

---

## Lago default setup

The Lago Docker image (`getlago/postgres-partman`) ships with pg_partman pre-installed. The provided `scripts/postgresql.conf` already configures the `pg_partman_bgw` approach with hourly maintenance. No additional setup is required when using the default Docker Compose configuration.
