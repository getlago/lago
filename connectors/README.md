# Lago Ingest Connectors

## Events format

- All events should respect the same format as [Lago API](https://doc.getlago.com/api-reference/events/usage)

```json
{
  "event": {
    "external_subscription_id": "string",
    "transaction_id": "unique_transaction_identifier",
    "code": "billable_metric_code",
    // Event Unix Timestamp
    "timestamp": 1620000000,
    "properties": {
      // Should respect the format of your billable metric
      "my_property": "my_value"
    },
    // Optional, used for the dynamic pricing feature, defaulted to 0
    "precise_total_amount_cents": 1000
  }
}
```

## Configuration

### Environment Variables

|Environment Variable|Description|Required|
|---|---|---|
|LOG_LEVEL|Log level for your connector, default: info|No|

## SQS Connector

### Environment Variables

|Environment Variable|Description|Required|
|---|---|---|
|SQS_ENDPOINT|The endpoint of the SQS service|Yes|
|SQS_REGION|The region of the SQS service|Yes|
|SQS_KEY_ID|The AWS access key id|Yes|
|SQS_KEY_SECRET|The AWS secret key|Yes|
|SQS_DLQ_ENDPOINT|The endpoint of the SQS service for the dead letter queue|No|
|ORGANIZATION_ID|Lago organization ID|Yes|
|KAFKA_BROKERS|Redpanda Broker|Yes|
|KAFKA_USER|Redpanda User|Yes|
|KAFKA_PASSWORD|Redpanda Password|Yes|
|KAFKA_TOPIC|Redpanda Topic to send events|Yes|

## HTTP Server

### Environment Variables

|Environment Variable|Description|Required|
|---|---|---|
|KAFKA_BROKERS|Redpanda Broker|Yes|
|KAFKA_USER|Redpanda User|Yes|
|KAFKA_PASSWORD|Redpanda Password|Yes|
|KAFKA_TOPIC|Redpanda Topic to send events|Yes|
|KAFKA_TLS|Enable TLS for Kafka connection, default: false|No|
|KAFKA_BATCH_COUNT|Number of messages to batch before sending, default: 100|No|
|KAFKA_BATCH_BYTE_SIZE|Maximum size in bytes for batching, default: 1000000 (1MB)|No|
|KAFKA_BATCH_PERIOD|Time period for batching, default: 1s|No|

