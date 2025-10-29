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

## Development

### Running

```shell
lago up -d events-processor
```

### Testing

```shell
lago exec events-processor go test ./...
```

## Configuration

This app requires some env vars

| Variable                                    | Description                                                                                   |
|---------------------------------------------|-----------------------------------------------------------------------------------------------|
| ENV                                         | Set as `production` to not load `.env` file                                                   |
| DATABASE_URL                                | PostgreSQL server URL (eg: `postgresql://lago_user:lago_password@lago_server:5432/lago_db`)   |
| LAGO_KAFKA_BOOTSTRAP_SERVERS                | Kafka Brokers list URL with port (eg: `"redpanda:9092,kafka:9092"`)                                              |
| LAGO_KAFKA_RAW_EVENTS_TOPIC                 | Events Kafka Topic (eg: `events_raw`)                                                         |
| LAGO_KAFKA_ENRICHED_EVENTS_TOPIC            | Events Enriched Kafka Topic (eg: `events_enriched`)                                           |
| LAGO_KAFKA_ENRICHED_EVENTS_EXPANDED_TOPIC   | Events Enriched Expanded Kafka Topic (eg: `events_enriched_expanded`)                         |
| LAGO_KAFKA_EVENTS_CHARGED_IN_ADVANCE_TOPIC  | Events Charge In Advance Kafka Topic (eg: `events_charge_in_advance`)                         |
| LAGO_KAFKA_EVENTS_DEAD_LETTER_TOPIC         | Events Dead Letter Queue (eg: `events_dead_letter`)                                           |
| LAGO_KAFKA_CONSUMER_GROUP                   | Kafka Consumer Group Name for Post Processing                                                 |
| LAGO_REDIS_STORE_URL                        | Redis URL to store subscription refresh IDs                                                   |
| LAGO_REDIS_CACHE_URL                        | Redis URL to store charge usage cache entries                                                 |


Additionally there's a few optional environment variables

| Variable                      | Description                                                                                                                        |
|-------------------------------|------------------------------------------------------------------------------------------------------------------------------------|
| LAGO_REDIS_STORE_DB           | Redis database number to use for the store (default: 0)                                                                            |
| LAGO_REDIS_STORE_PASSWORD     | Password for the Redis store (if required)                                                                                         |
| LAGO_REDIS_STORE_TLS          | Redis TLS configuration for the Redis store (default: false)                                                                       |
| LAGO_REDIS_CACHE_DB           | Redis database number to use for the cache (default: 0)                                                                            |
| LAGO_REDIS_CACHE_PASSWORD     | Password for the Redis cache (if required)                                                                                         |
| LAGO_REDIS_CACHE_TLS          | Redis TLS configuration for charge usage cache entries (default: false)                                                            |
| LAGO_KAFKA_TLS                | Set to `true` if your broker uses TLS termination                                                                                  |
| LAGO_KAFKA_SCRAM_ALGORITHM    | Your Broker SCRAM algo, supported values are `SCRAM-SHA-256` and `SCRAM-SHA-512`. <br> If you provide a SCRAM Algo, `LAGO_KAFKA_USERNAME` and `LAGO_KAFKA_PASSWORD` are required |
| LAGO_KAFKA_USERNAME           | If your broker needs auth, your Kafka Username                                                                                     |
| LAGO_KAFKA_PASSWORD           | If your broker needs auth, your Kafka password                                                                                     |
| OTEL_SERVICE_NAME             | OpenTelemetry service name (eg: `events-processor`)                                                                                |
| OTEL_EXPORTER_OTLP_ENDPOINT   | OpenTelemetry server URL. Setting this environment variable will enable tracing                                                    |
| OTEL_INSECURE                 | Set to `true` to use the insecure mode of OpenTelemetry                                                                            |
