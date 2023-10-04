# Apache Iceberg Sink Connector
The Apache Iceberg Sink Connector for Kafka Connect is a sink connector for writing data from Kafka into Iceberg tables.

# Features
* Commit coordination for centralized Iceberg commits
* Exactly-once delivery semantics
* Multi-table fan-out
* Row mutations (update/delete rows), upsert mode
* Evolution of table schema to match record schema
* Field name mapping via Iceberg’s column mapping functionality

# Installation
The Apache Iceberg Sink Connector is under active development, with early access builds available under
[Releases](https://github.com/tabular-io/iceberg-kafka-connect/releases). You can build the connector
zip archive yourself by running:
```bash
./gradlew -xtest clean build
```
The zip archive will be found under `./kafka-connect-runtime/build/distributions`.

# Configuration

| Property                                  | Description                                                                                                   |
|-------------------------------------------|---------------------------------------------------------------------------------------------------------------|
| iceberg.tables                            | Comma-separated list of destination tables                                                                    |
| iceberg.tables.dynamic.enabled            | Set to `true` to route to a table specified in `routeField` instead of using `routeRegex`, default is `false` |
| iceberg.tables.routeField                 | For multi-table fan-out, the name of the field used to route records to tables                                |
| iceberg.tables.defaultCommitBranch        | Default branch for commits, main is used if not specified                                                     |
| iceberg.tables.cdcField                   | Name of the field containing the CDC operation, `I`, `U`, or `D`, default is none                             |
| iceberg.tables.upsertModeEnabled          | Set to `true` to enable upsert mode, default is `false`                                                       |
| iceberg.tables.autoCreateEnabled          | Set to `true` to automatically create destination tables, default is `false`                                  |
| iceberg.tables.evolveSchemaEnabled        | Set to `true` to add any missing record fields to the table schema, default is `false`                        |
| iceberg.table.\<table name\>.idColumns    | Comma-separated list of columns that identify a row in the table (primary key)                                |
| iceberg.table.\<table name\>.routeRegex   | The regex used to match a record's `routeField` to a table                                                    |
| iceberg.table.\<table name\>.commitBranch | Table-specific branch for commits, use `iceberg.tables.defaultCommitBranch` if not specified                  |
| iceberg.control.topic                     | Name of the control topic, default is `control-iceberg`                                                       |
| iceberg.control.group.id                  | Name of the consumer group to store offsets, default is `cg-control-<connector name>`                         |
| iceberg.control.commitIntervalMs          | Commit interval in msec, default is 300,000 (5 min)                                                           |
| iceberg.control.commitTimeoutMs           | Commit timeout interval in msec, default is 30,000 (30 sec)                                                   |
| iceberg.control.commitThreads             | Number of threads to use for commits, default is (cores * 2)                                                  |
| iceberg.catalog                           | Name of the catalog, default is `iceberg`                                                                     |
| iceberg.catalog.*                         | Properties passed through to Iceberg catalog initialization                                                   |
| iceberg.hadoop-conf-dir                   | If specified, Hadoop config files in this directory will be loaded                                            |
| iceberg.hadoop.*                          | Properties passed through to the Hadoop configuration                                                         |
| iceberg.kafka.*                           | Properties passed through to control topic Kafka client initialization                                        |

If `iceberg.tables.dynamic.enabled` is `false` (the default) then you must specify `iceberg.tables`. If
`iceberg.tables.dynamic.enabled` is `true` then you must specify `iceberg.tables.routeField` which will
contain the name of the table. Enabling `iceberg.tables.upsertModeEnabled` will cause all appends to be
preceded by an equality delete. Both CDC and upsert mode require an Iceberg V2 table with identity fields
defined.

## Kafka configuration

By default the connector will attempt to use Kafka client config from the worker properties for connecting to
the control topic. If that config cannot be read for some reason, Kafka client settings
can be set explicitly using `iceberg.kafka.*` properties.

### Source topic offsets

Source topic offsets are stored in two different consumer groups. The first is the sink-managed consumer
group defined by the `iceberg.control.group.id` property. The second is the Kafka Connect managed
consumer group which is named `connect-<connector name>` by default. The sink-managed consumer
group is used by the sink to achieve exactly-once processing. The Kafka Connect consumer group is
only used as a fallback if the sink-managed consumer group is missing. To reset the offsets,
both consumer groups need to be reset.

### Message format

Messages should be converted to a struct or map using the appropriate Kafka Connect converter.

## Catalog configuration

The `iceberg.catalog.*` properties are required for connecting to the Iceberg catalog. The core catalog
types are included in the default distribution, including REST, Glue, DynamoDB, Hadoop, Nessie,
JDBC, and Hive. JDBC drivers are not included in the default distribution, so you will need to include
those if needed. When using a Hive catalog, you can use the distribution that includes the Hive metastore client,
otherwise you will need to include that yourself.

To set the catalog type, you can set `iceberg.catalog.type` to `rest`, `hive`, or `hadoop`. For other
catalog types, you need to instead set `iceberg.catalog.catalog-impl` to the name of the catalog class.

### REST example
```
"iceberg.catalog.type": "rest",
"iceberg.catalog.uri": "https://catalog-service",
"iceberg.catalog.credential": "<credential>",
"iceberg.catalog.warehouse": "<warehouse>",
```

### Hive example
NOTE: Use the distribution that includes the HMS client (or include the HMS client yourself). Use `S3FileIO` when
using S3 for storage (the default is `HadoopFileIO` with `HiveCatalog`).
```
"iceberg.catalog.type": "hive",
"iceberg.catalog.uri": "thrift://hive:9083",
"iceberg.catalog.io-impl": "org.apache.iceberg.aws.s3.S3FileIO",
"iceberg.catalog.warehouse": "s3a://bucket/warehouse",
"iceberg.catalog.client.region": "us-east-1",
"iceberg.catalog.s3.access-key-id": "<AWS access>",
"iceberg.catalog.s3.secret-access-key": "<AWS secret>",
```

### Glue example
```
"iceberg.catalog.catalog-impl": "org.apache.iceberg.aws.glue.GlueCatalog",
"iceberg.catalog.warehouse": "s3a://bucket/warehouse",
"iceberg.catalog.io-impl": "org.apache.iceberg.aws.s3.S3FileIO",
```

### Nessie example
```
"iceberg.catalog.catalog-impl": "org.apache.iceberg.nessie.NessieCatalog",
"iceberg.catalog.uri": "http://localhost:19120/api/v1",
"iceberg.catalog.ref": "main",
"iceberg.catalog.warehouse": "s3a://bucket/warehouse",
"iceberg.catalog.io-impl": "org.apache.iceberg.aws.s3.S3FileIO",
```

### Notes
Depending on your setup, you may need to also set `iceberg.catalog.s3.endpoint`, `iceberg.catalog.s3.staging-dir`,
or `iceberg.catalog.s3.path-style-access`. See the [Iceberg docs](https://iceberg.apache.org/docs/latest/) for
full details on configuring catalogs.

## Hadoop configuration

When using HDFS or Hive, the sink will initialize the Hadoop configuration. First, config files
from the classpath are loaded. Next, if `iceberg.hadoop-conf-dir` is specified, config files
are loaded from that location. Finally, any `iceberg.hadoop.*` properties from the sink config are
applied. When merging these, the order of precedence is sink config > config dir > classpath.

# Examples

## Initial setup

### Source topic
This assumes the source topic already exists and is named `events`.

### Control topic
If your Kafka cluster has `auto.create.topics.enable` set to `true` (the default), then the control topic will be automatically created. If not, then you will need to create the topic first. The default topic name is `control-iceberg`:
```bash
bin/kafka-topics  \
  --command-config command-config.props \
  --bootstrap-server ${CONNECT_BOOTSTRAP_SERVERS} \
  --create \
  --topic control-iceberg \
  --partitions 1
```
*NOTE: Clusters running on Confluent Cloud have `auto.create.topics.enable` set to `false` by default.*

### Iceberg catalog configuration
Configuration properties with the prefix `iceberg.catalog.` will be passed to Iceberg catalog initialization.
See the [Iceberg docs](https://iceberg.apache.org/docs/latest/) for details on how to configure
a particular catalog.

## Single destination table
This example writes all incoming records to a single table.

### Create the destination table
```sql
CREATE TABLE default.events (
    id STRING,
    type STRING,
    ts TIMESTAMP,
    payload STRING)
PARTITIONED BY (hours(ts))
```

### Connector config
This example config connects to a Iceberg REST catalog.
```json
{
"name": "events-sink",
"config": {
    "connector.class": "io.tabular.iceberg.connect.IcebergSinkConnector",
    "tasks.max": "2",
    "topics": "events",
    "iceberg.tables": "default.events",
    "iceberg.catalog.type": "rest",
    "iceberg.catalog.uri": "https://localhost",
    "iceberg.catalog.credential": "<credential>",
    "iceberg.catalog.warehouse": "<warehouse name>"
    }
}
```

## Multi-table fan-out, static routing
This example writes records with `type` set to `list` to the table `default.events_list`, and
writes records with `type` set to `create` to the table `default.events_create`. Other records
will be skipped.

### Create two destination tables
```sql
CREATE TABLE default.events_list (
    id STRING,
    type STRING,
    ts TIMESTAMP,
    payload STRING)
PARTITIONED BY (hours(ts));

CREATE TABLE default.events_create (
    id STRING,
    type STRING,
    ts TIMESTAMP,
    payload STRING)
PARTITIONED BY (hours(ts));
```

### Connector config
```json
{
"name": "events-sink",
"config": {
    "connector.class": "io.tabular.iceberg.connect.IcebergSinkConnector",
    "tasks.max": "2",
    "topics": "events",
    "iceberg.tables": "default.events_list,default.events_create",
    "iceberg.tables.routeField": "type",
    "iceberg.table.default.events_list.routeRegex": "list",
    "iceberg.table.default.events_create.routeRegex": "create",
    "iceberg.catalog.type": "rest",
    "iceberg.catalog.uri": "https://localhost",
    "iceberg.catalog.credential": "<credential>",
    "iceberg.catalog.warehouse": "<warehouse name>"
    }
}
```

## Multi-table fan-out, dynamic routing
This example writes to tables with names from the value in the `db_table` field. If a table with
the name does not exist, then the record will be skipped. For example, if the record's `db_table`
field is set to `default.events_list`, then the record is written to the `default.events_list` table.

### Create two destination tables
See above for creating two tables.

### Connector config
```json
{
"name": "events-sink",
"config": {
    "connector.class": "io.tabular.iceberg.connect.IcebergSinkConnector",
    "tasks.max": "2",
    "topics": "events",
    "iceberg.tables.dynamic.enabled": "true",
    "iceberg.tables.routeField": "db_table",
    "iceberg.catalog.type": "rest",
    "iceberg.catalog.uri": "https://localhost",
    "iceberg.catalog.credential": "<credential>",
    "iceberg.catalog.warehouse": "<warehouse name>"
    }
}
```

## Change data capture
This example applies inserts, updates, and deletes based on the value of a field in the record.
For example, if the `_cdc_op` field is set to `I` then the record is inserted, if `U` then it is
upserted, and if `D` then it is deleted. This requires that the table be in Iceberg v2 format.
The Iceberg identifier field(s) are used to identify a row, if that is not set for the table,
then the `iceberg.tables.idColumns`configuration can be set instead. CDC can be combined with
multi-table fan-out.

### Create the destination table
See above for creating the table

### Connector config
```json
{
"name": "events-sink",
"config": {
    "connector.class": "io.tabular.iceberg.connect.IcebergSinkConnector",
    "tasks.max": "2",
    "topics": "events",
    "iceberg.tables": "default.events",
    "iceberg.tables.cdcField": "_cdc_op",
    "iceberg.catalog.type": "rest",
    "iceberg.catalog.uri": "https://localhost",
    "iceberg.catalog.credential": "<credential>",
    "iceberg.catalog.warehouse": "<warehouse name>"
    }
}
```

### AWS DMS example (experimental)

The `io.tabular.iceberg.connect.transforms.DmsTransform` SMT can be used to convert an AWS DMS
message for use by the sink. This transform will promote the data fields to top level, and add
three metadata fields. These fields are `_cdc_op` for operation type (I, U, D), `_cdc_table` for
the source table name, and `_cdc_ts` for the operation timestamp.

Here is an example config that uses this transform to apply updates to an Iceberg table. The
`routeRegex` is defined to ensure the correct message is routed to the table.

```json
{
"name": "dms-cdc-sink",
"config": {
    "connector.class": "io.tabular.iceberg.connect.IcebergSinkConnector",
    "tasks.max": "2",
    "topics": "dms-topic",
    "key.converter": "org.apache.kafka.connect.storage.StringConverter",
    "value.converter": "org.apache.kafka.connect.json.JsonConverter",
    "value.converter.schemas.enable": "false",
    "transforms": "dms",
    "transforms.dms.type": "io.tabular.iceberg.connect.transforms.DmsTransform",
    "iceberg.tables": "default.dms_test",
    "iceberg.tables.cdcField": "_cdc_op",
    "iceberg.tables.routeField": "_cdc_table",
    "iceberg.table.default.dms_test.routeRegex": "src_db.src_table",
    "iceberg.catalog.type": "rest",
    "iceberg.catalog.uri": "https://localhost",
    "iceberg.catalog.credential": "<credential>",
    "iceberg.catalog.warehouse": "<warehouse name>"
    }
}
```
