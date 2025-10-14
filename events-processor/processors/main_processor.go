package processors

import (
	"context"
	"fmt"
	"log/slog"
	"os"
	"os/signal"
	"syscall"

	"github.com/twmb/franz-go/pkg/kgo"

	tracer "github.com/getlago/lago/events-processor/config"
	"github.com/getlago/lago/events-processor/config/database"
	"github.com/getlago/lago/events-processor/config/kafka"
	"github.com/getlago/lago/events-processor/config/redis"
	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/processors/events_processor"
	"github.com/getlago/lago/events-processor/utils"
)

var (
	logger           *slog.Logger
	processor        *events_processor.EventProcessor
	apiStore         *models.ApiStore
	kafkaConfig      kafka.ServerConfig
	chargeCacheStore *models.ChargeCache
)

const (
	envEnv                                       = "ENV"
	envLagoEventsProcessorDatabaseMaxConnections = "LAGO_EVENTS_PROCESSOR_DATABASE_MAX_CONNECTIONS"
	envLagoKafkaBootstrapServers                 = "LAGO_KAFKA_BOOTSTRAP_SERVERS"
	envLagoKafkaConsumerGroup                    = "LAGO_KAFKA_CONSUMER_GROUP"
	envLagoKafkaEnrichedEventsExpandedTopic      = "LAGO_KAFKA_ENRICHED_EVENTS_EXPANDED_TOPIC"
	envLagoKafkaEnrichedEventsTopic              = "LAGO_KAFKA_ENRICHED_EVENTS_TOPIC"
	envLagoKafkaEventsChargedInAdvanceTopic      = "LAGO_KAFKA_EVENTS_CHARGED_IN_ADVANCE_TOPIC"
	envLagoKafkaEventsDeadLetterTopic            = "LAGO_KAFKA_EVENTS_DEAD_LETTER_TOPIC"
	envLagoKafkaPassword                         = "LAGO_KAFKA_PASSWORD"
	envLagoKafkaRawEventsTopic                   = "LAGO_KAFKA_RAW_EVENTS_TOPIC"
	envLagoKafkaScramAlgorithm                   = "LAGO_KAFKA_SCRAM_ALGORITHM"
	envLagoKafkaTLS                              = "LAGO_KAFKA_TLS"
	envLagoKafkaUsername                         = "LAGO_KAFKA_USERNAME"
	envLagoRedisCacheDB                          = "LAGO_REDIS_CACHE_DB"
	envLagoRedisCachePassword                    = "LAGO_REDIS_CACHE_PASSWORD"
	envLagoRedisCacheURL                         = "LAGO_REDIS_CACHE_URL"
	envLagoRedisStoreDB                          = "LAGO_REDIS_STORE_DB"
	envLagoRedisStorePassword                    = "LAGO_REDIS_STORE_PASSWORD"
	envLagoRedisStoreURL                         = "LAGO_REDIS_STORE_URL"
	envOtelExporterOtlpEndpoint                  = "OTEL_EXPORTER_OTLP_ENDPOINT"
	envOtelInsecure                              = "OTEL_INSECURE"
	envOtelServiceName                           = "OTEL_SERVICE_NAME"
)

func initProducer(ctx context.Context, topicEnv string) utils.Result[*kafka.Producer] {
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

	err = producer.Ping(ctx)
	if err != nil {
		return utils.FailedResult[*kafka.Producer](err)
	}

	return utils.SuccessResult(producer)
}

func initFlagStore(ctx context.Context, name string) (*models.FlagStore, error) {
	redisDb, err := utils.GetEnvAsInt(envLagoRedisStoreDB, 0)
	if err != nil {
		return nil, err
	}

	redisConfig := redis.RedisConfig{
		Address:  os.Getenv(envLagoRedisStoreURL),
		Password: os.Getenv(envLagoRedisStorePassword),
		DB:       redisDb,
		UseTLS:   os.Getenv(envEnv) == "production",
	}

	db, err := redis.NewRedisDB(ctx, redisConfig)
	if err != nil {
		return nil, err
	}

	return models.NewFlagStore(ctx, db, name), nil
}

func initChargeCacheStore(ctx context.Context) (*models.ChargeCache, error) {
	redisDb, err := utils.GetEnvAsInt(envLagoRedisCacheDB, 0)
	if err != nil {
		return nil, err
	}

	redisConfig := redis.RedisConfig{
		Address:  os.Getenv(envLagoRedisCacheURL),
		Password: os.Getenv(envLagoRedisCachePassword),
		DB:       redisDb,
		UseTLS:   false,
	}

	db, err := redis.NewRedisDB(ctx, redisConfig)
	if err != nil {
		return nil, err
	}

	cacheStore := models.NewCacheStore(ctx, db)
	var store models.Cacher = cacheStore
	chargeStore := models.NewChargeCache(&store)

	return chargeStore, nil
}

func StartProcessingEvents() {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	setupGracefulShutdown(cancel)

	logger = slog.New(slog.NewJSONHandler(os.Stdout, nil)).
		With("service", "post_process")
	slog.SetDefault(logger)

	otelEndpoint := os.Getenv(envOtelExporterOtlpEndpoint)
	if otelEndpoint != "" {
		telemetryCfg := tracer.TracerConfig{
			ServiceName: os.Getenv(envOtelServiceName),
			EndpointURL: otelEndpoint,
			Insecure:    os.Getenv(envOtelInsecure),
		}
		tracer.InitOTLPTracer(telemetryCfg)
	}

	kafkaConfig = kafka.ServerConfig{
		ScramAlgorithm: os.Getenv(envLagoKafkaScramAlgorithm),
		TLS:            os.Getenv(envLagoKafkaTLS) == "true",
		Server:         os.Getenv(envLagoKafkaBootstrapServers),
		UseTelemetry:   otelEndpoint != "",
		UserName:       os.Getenv(envLagoKafkaUsername),
		Password:       os.Getenv(envLagoKafkaPassword),
	}

	eventsEnrichedProducerResult := initProducer(ctx, envLagoKafkaEnrichedEventsTopic)
	if eventsEnrichedProducerResult.Failure() {
		logger.Error(eventsEnrichedProducerResult.ErrorMsg())
		utils.CaptureErrorResult(eventsEnrichedProducerResult)
		panic(eventsEnrichedProducerResult.ErrorMessage())
	}

	eventsEnrichedExpandedProducerResult := initProducer(ctx, envLagoKafkaEnrichedEventsExpandedTopic)
	if eventsEnrichedExpandedProducerResult.Failure() {
		logger.Error(eventsEnrichedExpandedProducerResult.ErrorMsg())
		utils.CaptureErrorResult(eventsEnrichedExpandedProducerResult)
		panic(eventsEnrichedExpandedProducerResult.ErrorMessage())
	}

	eventsInAdvanceProducerResult := initProducer(ctx, envLagoKafkaEventsChargedInAdvanceTopic)
	if eventsInAdvanceProducerResult.Failure() {
		logger.Error(eventsInAdvanceProducerResult.ErrorMsg())
		utils.CaptureErrorResult(eventsInAdvanceProducerResult)
		panic(eventsInAdvanceProducerResult.ErrorMessage())
	}

	eventsDeadLetterQueueResult := initProducer(ctx, envLagoKafkaEventsDeadLetterTopic)
	if eventsDeadLetterQueueResult.Failure() {
		logger.Error(eventsDeadLetterQueueResult.ErrorMsg())
		utils.CaptureErrorResult(eventsDeadLetterQueueResult)
		panic(eventsDeadLetterQueueResult.ErrorMessage())
	}

	maxConns, err := utils.GetEnvAsInt(envLagoEventsProcessorDatabaseMaxConnections, 200)
	if err != nil {
		logger.Error("Error converting max connections into integer", slog.String("error", err.Error()))
		utils.CaptureError(err)
		panic(err.Error())
	}

	dbConfig := database.DBConfig{
		Url:      os.Getenv("DATABASE_URL"),
		MaxConns: int32(maxConns),
	}

	db, err := database.NewConnection(dbConfig)
	if err != nil {
		logger.Error("Error connecting to the database", slog.String("error", err.Error()))
		utils.CaptureError(err)
		panic(err.Error())
	}
	apiStore = models.NewApiStore(db)
	defer db.Close()

	flagger, err := initFlagStore(ctx, "subscription_refreshed")
	if err != nil {
		logger.Error("Error connecting to the flag store", slog.String("error", err.Error()))
		utils.CaptureError(err)
		panic(err.Error())
	}
	defer flagger.Close()

	cacher, err := initChargeCacheStore(ctx)
	if err != nil {
		logger.Error("Error connecting to the charge cache store", slog.String("error", err.Error()))
		utils.CaptureError(err)
		panic(err.Error())
	}
	chargeCacheStore = cacher
	defer chargeCacheStore.CacheStore.Close()

	processor = events_processor.NewEventProcessor(
		logger,
		events_processor.NewEventEnrichmentService(apiStore),
		events_processor.NewEventProducerService(
			eventsEnrichedProducerResult.Value(),
			eventsEnrichedExpandedProducerResult.Value(),
			eventsInAdvanceProducerResult.Value(),
			eventsDeadLetterQueueResult.Value(),
			logger,
		),
		events_processor.NewSubscriptionRefreshService(flagger),
		events_processor.NewCacheService(chargeCacheStore),
	)

	cg, err := kafka.NewConsumerGroup(
		kafkaConfig,
		&kafka.ConsumerGroupConfig{
			Topic:         os.Getenv(envLagoKafkaRawEventsTopic),
			ConsumerGroup: os.Getenv(envLagoKafkaConsumerGroup),
			ProcessRecords: func(ctx context.Context, records []*kgo.Record) []*kgo.Record {
				return processor.ProcessEvents(ctx, records)
			},
		})
	if err != nil {
		logger.Error("Error starting the event consumer", slog.String("error", err.Error()))
		utils.CaptureError(err)
		panic(err.Error())
	}

	logger.Info("Starting event consumer")
	if err := cg.Start(ctx); err != nil && err != context.Canceled {
		logger.Error("Consumer stopped with error", slog.String("error", err.Error()))
		utils.CaptureError(err)
	}

	logger.Info("Event processor stopped")
}

func setupGracefulShutdown(cancel context.CancelFunc) {
	signChan := make(chan os.Signal, 1)
	signal.Notify(signChan, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		sig := <-signChan
		logger.Info("Received shutdown signal", slog.String("signal", sig.String()))
		cancel()
	}()
}
