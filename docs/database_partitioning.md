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
```

> Do NOT create a manual `DEFAULT` partition here. `partman.create_parent` (step 5) creates pg_partman's own default partition (`enriched_events_default`). A manually created one collides with it (`relation "enriched_events_default" already exists`) and aborts registration.

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

### 5. Register with pg_partman

Register FIRST, while the parent table is still empty. This creates the monthly partitions and pg_partman's own default partition:

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

> `p_start_partition` must be at or before your oldest row in `enriched_events_old`. Anything earlier has no covering partition and lands in the default partition.
>
> Registration must happen before the data move (step 6). Copying rows first leaves them all in the default partition, and PostgreSQL then refuses to create the dated partitions covering those rows (`partition constraint would be violated`).

### 6. Migrate existing data

Only now copy the historical rows. Every row routes directly into its monthly partition:

```sql
INSERT INTO public.enriched_events
SELECT * FROM public.enriched_events_old;
```

> If the table is large, consider batching inserts or running this during a maintenance window.

### 7. Verify before dropping anything

This is the last point where a mistake is still recoverable (`enriched_events_old` still exists), so confirm the counts first:

```sql
SELECT count(*) FROM public.enriched_events_default; -- expect 0
SELECT count(*) FROM public.enriched_events; -- expect the old row count
```

If the default partition is not empty, stop: check that `p_start_partition` covers your oldest row before retrying. Do not drop the old table until the default count is 0 and the total matches.

### 8. Drop the old table last

```sql
DROP TABLE public.enriched_events_old;
```

Then trigger a first maintenance run to create future partitions per `p_premake`:

```sql
CALL partman.run_maintenance_proc();
```

> Note: `run_maintenance_proc()` only creates future partitions (and drops/detaches expired ones per `retention`). It does not move rows out of the default partition. Moving rows out of an already-populated default partition requires `partition_data_proc()` / `partition_data_time()`, which is exactly why this procedure registers (step 5) before moving data (step 6) instead of relying on maintenance afterwards.

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
