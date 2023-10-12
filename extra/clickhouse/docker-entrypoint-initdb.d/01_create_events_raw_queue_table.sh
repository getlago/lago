#!/bin/bash
set -e 
clickhouse client -n <<-EOSQL
CREATE TABLE default.events_raw_queue
(
	organization_id String,
	external_customer_id String,
	external_subscription_id String,
	transaction_id String,
	timestamp DateTime,
	code String,
	properties String
) ENGINE = Kafka()
SETTINGS
	kafka_broker_list = 'redpanda:9092',
	kafka_topic_list = 'events-raw',
	kafka_group_name = 'clickhouse',
	kafka_format = 'JSONEachRow';
EOSQL
