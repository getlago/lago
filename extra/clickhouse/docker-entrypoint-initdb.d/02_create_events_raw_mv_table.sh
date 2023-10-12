#!/bin/bash
set -e 
clickhouse client -n <<-EOSQL
CREATE MATERIALIZED VIEW events_raw_mv TO events_raw AS
SELECT *
FROM events_raw_queue;
EOSQL