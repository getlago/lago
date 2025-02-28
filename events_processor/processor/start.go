package processor

import (
	"context"
	"fmt"
	"log/slog"
	"os"

	tracer "github.com/getlago/lago/events-processor/config"
	"github.com/getlago/lago/events-processor/config/kafka"
	"github.com/getlago/lago/events-processor/database"
	"github.com/getlago/lago/events-processor/utils"
	"github.com/twmb/franz-go/pkg/kgo"
)

var (
	ctx                     context.Context
	logger                  *slog.Logger
	err                     error
	eventsEnrichedProducer  *kafka.Producer
	eventsInAdvanceProducer *kafka.Producer
	eventsDeadLetterQueue   *kafka.Producer
	db                      *database.DB
	kafkaConfig             kafka.ServerConfig
)

func initProducer(context context.Context, topicEnv string) utils.Result[*kafka.Producer] {
	if os.Getenv(topicEnv) == "" {
		return utils.FailedResult[*kafka.Producer](fmt.Errorf("%s variable is required", topicEnv))
	}

	topic := os.Getenv(topicEnv)

	producer, err := kafka.NewProducer(
		kafkaConfig,
		&kafka.ProducerConfig{
			Topic: topic,
		})
	if err != nil {
		return utils.FailedResult[*kafka.Producer](err)
	}

	err = producer.Ping(context)
	if err != nil {
		return utils.FailedResult[*kafka.Producer](err)
	}

	return utils.SuccessResult(producer)
}

func StartProcessingEvents() {
	ctx = context.Background()

	logger = slog.New(slog.NewJSONHandler(os.Stdout, nil)).
		With("service", "post_process")
	slog.SetDefault(logger)

	if os.Getenv("ENV") == "production" {
		telemetryCfg := tracer.TracerConfig{
			ServiceName: os.Getenv("OTEL_SERVICE_NAME"),
			EndpointURL: os.Getenv("OTEL_EXPORTER_OTLP_ENDPOINT"),
			Insecure:    os.Getenv("OTEL_INSECURE"),
		}
		tracer.InitOTLPTracer(telemetryCfg)
	}

	kafkaConfig = kafka.ServerConfig{
		ScramAlgorithm: os.Getenv("LAGO_KAFKA_SCRAM_ALGORITHM"),
		TLS:            os.Getenv("LAGO_KAFKA_TLS") == "true",
		Server:         os.Getenv("LAGO_KAFKA_BOOTSTRAP_SERVERS"),
		UseTelemetry:   os.Getenv("ENV") == "production",
		UserName:       os.Getenv("LAGO_KAFKA_USERNAME"),
		Password:       os.Getenv("LAGO_KAFKA_PASSWORD"),
	}

	eventsEnrichedProducerResult := initProducer(ctx, "LAGO_KAFKA_EVENTS_ENRICHED_TOPIC")
	if eventsEnrichedProducerResult.Failure() {
		logger.Error(eventsEnrichedProducerResult.ErrorMsg())
		os.Exit(1)
	}
	eventsEnrichedProducer = eventsEnrichedProducerResult.Value()

	eventsInAdvanceProducerResult := initProducer(ctx, "LAGO_KAFKA_EVENTS_CHARGED_IN_ADVANCE_TOPIC")
	if eventsInAdvanceProducerResult.Failure() {
		logger.Error(eventsInAdvanceProducerResult.ErrorMsg())
		os.Exit(1)
	}
	eventsInAdvanceProducer = eventsInAdvanceProducerResult.Value()

	eventsDeadLetterQueueResult := initProducer(ctx, "LAGO_KAFKA_EVENTS_DEAD_LETTER_QUEUE")
	if eventsDeadLetterQueueResult.Failure() {
		logger.Error(eventsDeadLetterQueueResult.ErrorMsg())
		os.Exit(1)
	}
	eventsDeadLetterQueue = eventsDeadLetterQueueResult.Value()

	cg, err := kafka.NewConsumerGroup(
		kafkaConfig,
		&kafka.ConsumerGroupConfig{
			Topic:         os.Getenv("LAGO_KAFKA_RAW_EVENTS_TOPIC"),
			ConsumerGroup: os.Getenv("LAGO_KAFKA_CONSUMER_GROUP"),
			ProcessRecords: func(records []*kgo.Record) []*kgo.Record {
				return processEvents(records)
			},
		})
	if err != nil {
		logger.Error("Error starting the event consumer", slog.String("error", err.Error()))
		os.Exit(1)
	}

	db, err = database.NewConnection(os.Getenv("DATABASE_URL"))
	if err != nil {
		logger.Error("Error connecting to the database", slog.String("error", err.Error()))
		os.Exit(1)
	}

	cg.Start()
}
