# Lago Events Processor

High throughput events processor for Lago.
This service is in charge of providing a post-process for events in high volume scenarios.

This service need to be configured with Clickhouse and Redpanda. Please contact us for further informations.


## How to run it

With the docker compose environment:

```shell
go build -o event_processors .

./event_processors
```

## Configuration

This app requires some env vars

|Variable|Description|
|---|---|
|ENV|Set as `production` to not load `.env` file|
| DATABASE_URL | PostgreSQL server URL (eg: `postgresql://lago_user:lago_password@lago_server:5432/lago_db`) |
| LAGO_KAFKA_BOOTSTRAP_SERVERS | Kafka Broker URL with port (eg: `redpanda:9092`) |
| LAGO_KAFKA_USERNAME | If your broker needs auth, your Kafka Username |
| LAGO_KAFKA_PASSWORD | If your broker needs auth, your Kafka password |
| LAGO_KAFKA_SCRAM_ALGORITHM | Your Broker SCRAM algo, supported values are `SCRAM-SHA-256` and `SCRAM-SHA-512`. If your provide a SCRAM Algo, `KAFKA_USERNAME` and `KAFKA_PASSWORD` are required |
| LAGO_KAFKA_TLS | Set to `true` if your broker use a TLS termination |
| LAGO_KAFKA_RAW_EVENTS_TOPIC | Events Kafka Topic (eg: `events_raw`) |
| LAGO_KAFKA_EVENTS_ENRICHED_TOPIC | Events Enriched Kafka Topic (eg: `events_enriched`) |
| LAGO_KAFKA_EVENTS_CHARGED_IN_ADVANCE_TOPIC | Events Charge In Advance Kafka Topic (eg: `events_charge_in_advance`) |
| LAGO_KAFKA_EVENTS_DEAD_LETTER_QUEUE | Events Dead Letter Queue  (eg: `events_dead_letter_queue`) |
| LAGO_KAFKA_CONSUMER_GROUP | Kafka Consumer Group Name for Post Processing |
| OTEL_SERVICE_NAME | OpenTelemetry service name (eg: `events-processor`) |
| OTEL_EXPORTER_OTLP_ENDPOINT | OpenTelemetry server URL |
| OTEL_INSECURE | Set to `true` to use the insecure mode of OpenTelemetry |
