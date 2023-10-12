#!/bin/bash
set -e 
clickhouse client -n <<-EOSQL
CREATE TABLE events_raw
(
	organization_id String,
	external_customer_id String,
	external_subscription_id String,
	transaction_id String,
	timestamp DateTime,
	code String,
	properties String
)
ENGINE = MergeTree ORDER BY (timestamp)
TTL 
  timestamp TO VOLUME 'default',
  timestamp + INTERVAL 90 DAY TO VOLUME 'cold';
EOSQL