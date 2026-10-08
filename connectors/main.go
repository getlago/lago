// Trimmed Redpanda Connect binary for Lago's ingest connectors.
//
// Upstream's docker.redpanda.com/redpandadata/connect image links
// public/components/all — every component Redpanda Connect ships (~80
// packages: amqp, postgres, mongodb, snowflake, thrift, git, ...). Lago's
// configs in this directory use four of them:
//
//	http.yml      http_server, kafka_franz, broker, mapping, sync_response
//	sqs.yml       aws_sqs,     kafka_franz, switch,  mapping
//	kinesis.yml   aws_kinesis (+ dynamodb checkpointing), kafka_franz
//
// Everything else was dead weight that still shipped its CVEs: amqp091-go
// and jackc/pgx alone carried 5 of the image's 14 critical findings, for
// connectors nothing here references.
//
// Keep the import list in sync with the configs. A component used in a
// config but not imported here fails at `run` with an unrecognised-field
// lint error, not silently.
package main

import (
	"context"

	"github.com/redpanda-data/benthos/v4/public/service"

	// aws_sqs, aws_kinesis (and the DynamoDB checkpoint table kinesis.yml uses)
	_ "github.com/redpanda-data/connect/v4/public/components/aws"
	// http_server input and sync_response output
	_ "github.com/redpanda-data/connect/v4/public/components/io"
	// kafka_franz input/output
	_ "github.com/redpanda-data/connect/v4/public/components/kafka"
	// prometheus metrics exporter — all three configs end with
	// `metrics: { prometheus: {} }`. Without this the binary builds fine and
	// then fails at `lint`/`run` with "unable to infer metrics type from
	// candidates: [prometheus]", which is how it was caught here.
	_ "github.com/redpanda-data/connect/v4/public/components/prometheus"
	// bloblang mapping, broker, switch, and the rest of the config-language core
	_ "github.com/redpanda-data/connect/v4/public/components/pure"
)

func main() {
	service.RunCLI(context.Background())
}
