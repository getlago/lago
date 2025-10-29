package processors

import (
	"context"
	"fmt"
	"log/slog"
	"os"

	"github.com/twmb/franz-go/pkg/kgo"

	tracer "github.com/getlago/lago/events-processor/config"
	"github.com/getlago/lago/events-processor/config/database"
	"github.com/getlago/lago/events-processor/config/kafka"
	"github.com/getlago/lago/events-processor/config/redis"
	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/processors/event_processors"
	"github.com/getlago/lago/events-processor/utils"
)

var (
	ctx              context.Context
	logger           *slog.Logger
	processor        *event_processors.EventProcessor
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
	envLagoRedisCacheTLS                         = "LAGO_REDIS_CACHE_TLS"
	envLagoRedisStoreDB                          = "LAGO_REDIS_STORE_DB"
	envLagoRedisStorePassword                    = "LAGO_REDIS_STORE_PASSWORD"
	envLagoRedisStoreURL                         = "LAGO_REDIS_STORE_URL"
	envLagoRedisStoreTLS                         = "LAGO_REDIS_STORE_TLS"
	envOtelExporterOtlpEndpoint                  = "OTEL_EXPORTER_OTLP_ENDPOINT"
	envOtelInsecure                              = "OTEL_INSECURE"
	envOtelServiceName                           = "OTEL_SERVICE_NAME"
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

func initFlagStore(name string) (*models.FlagStore, error) {
	redisDb, err := utils.GetEnvAsInt(envLagoRedisStoreDB, 0)
	if err != nil {
		return nil, err
	}

	// Deprecated: Use env LAGO_REDIS_STORE_TLS instead
	legacyTLS := os.Getenv(envEnv) == "production"

	redisConfig := redis.RedisConfig{
		Address:  os.Getenv(envLagoRedisStoreURL),
		Password: os.Getenv(envLagoRedisStorePassword),
		DB:       redisDb,
		UseTLS:   utils.GetEnvAsBool(envLagoRedisStoreTLS, legacyTLS),
	}

	db, err := redis.NewRedisDB(ctx, redisConfig)
	if err != nil {
		return nil, err
	}

	return models.NewFlagStore(ctx, db, name), nil
}

func initChargeCacheStore() (*models.ChargeCache, error) {
	redisDb, err := utils.GetEnvAsInt(envLagoRedisCacheDB, 0)
	if err != nil {
		return nil, err
	}

	redisConfig := redis.RedisConfig{
		Address:  os.Getenv(envLagoRedisCacheURL),
		Password: os.Getenv(envLagoRedisCachePassword),
		DB:       redisDb,
		UseTLS:   utils.GetEnvAsBool(envLagoRedisCacheTLS, false),
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
	ctx = context.Background()

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

	serverBrokers := utils.ParseBrokersEnv(os.Getenv(envLagoKafkaBootstrapServers))
	if len(serverBrokers) == 0 {
		logger.Error("brokers not found")
		panic("brokers not found")
	}

	kafkaConfig = kafka.ServerConfig{
		ScramAlgorithm: os.Getenv(envLagoKafkaScramAlgorithm),
		TLS:            os.Getenv(envLagoKafkaTLS) == "true",
		Servers:        serverBrokers,
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

	flagger, err := initFlagStore("subscription_refreshed")
	if err != nil {
		logger.Error("Error connecting to the flag store", slog.String("error", err.Error()))
		utils.CaptureError(err)
		panic(err.Error())
	}
	defer flagger.Close()

	cacher, err := initChargeCacheStore()
	if err != nil {
		logger.Error("Error connecting to the charge cache store", slog.String("error", err.Error()))
		utils.CaptureError(err)
		panic(err.Error())
	}
	chargeCacheStore = cacher
	defer chargeCacheStore.CacheStore.Close()

	processor = event_processors.NewEventProcessor(
		event_processors.NewEventEnrichmentService(apiStore),
		event_processors.NewEventProducerService(
			eventsEnrichedProducerResult.Value(),
			eventsEnrichedExpandedProducerResult.Value(),
			eventsInAdvanceProducerResult.Value(),
			eventsDeadLetterQueueResult.Value(),
			logger,
		),
		event_processors.NewSubscriptionRefreshService(flagger),
		event_processors.NewCacheService(chargeCacheStore),
	)

	cg, err := kafka.NewConsumerGroup(
		kafkaConfig,
		&kafka.ConsumerGroupConfig{
			Topic:         os.Getenv(envLagoKafkaRawEventsTopic),
			ConsumerGroup: os.Getenv(envLagoKafkaConsumerGroup),
			ProcessRecords: func(records []*kgo.Record) []*kgo.Record {
				return processEvents(records)
			},
		})
	if err != nil {
		logger.Error("Error starting the event consumer", slog.String("error", err.Error()))
		utils.CaptureError(err)
		panic(err.Error())
	}

	cg.Start()
}
