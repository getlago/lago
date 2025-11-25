# ClickHouse Kafka Connect Sink

## About
clickhouse-kafka-connect is the official Kafka Connect sink connector for [ClickHouse](https://clickhouse.com/).

The Kafka connector delivers data from a Kafka topic to a ClickHouse table.
## Documentation

See the [ClickHouse website](https://clickhouse.com/docs/en/integrations/kafka/clickhouse-kafka-connect-sink) for the full documentation entry.

## Design
For a full overview of the design and how exactly-once delivery semantics are achieved, see the [design document](./docs/DESIGN.md).

## Help
For additional help, please [file an issue in the repository](https://github.com/ClickHouse/clickhouse-kafka-connect/issues) or raise a question in [ClickHouse public Slack](https://clickhouse.com/slack).

## KeyToValue Transformation
We've created a transformation that allows you to convert a Kafka message key into a value.
This is useful when you want to store the key in a separate column in ClickHouse - by default, the column is `_key` and the type is String.

```sql
CREATE TABLE your_table_name
(
    `your_column_name` String,
    ...
    ...
    ...
    `_key` String
) ENGINE = MergeTree()
```

Simply add the transformation to your connector configuration:
    
```properties
transforms=keyToValue
transforms.keyToValue.type=com.clickhouse.kafka.connect.transforms.KeyToValue
transforms.keyToValue.field=_key
```

## Performance Testing

There is a dedicated gradle project in this repo - `benchmark` for performance testing. 
Please see its [README](./benchmark/README.md) for more information and how to run.