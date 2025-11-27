package processors

import (
	"context"
	"fmt"
	"log/slog"
	"os"

	"github.com/twmb/franz-go/pkg/kgo"

	"github.com/getlago/lago/events-processor/config/database"
	"github.com/getlago/lago/events-processor/config/kafka"
	"github.com/getlago/lago/events-processor/config/redis"
	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/processors/events_processor"
	"github.com/getlago/lago/events-processor/utils"
)

var (
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
	envLagoRedisCacheTLS                         = "LAGO_REDIS_CACHE_TLS"
	envLagoRedisStoreDB                          = "LAGO_REDIS_STORE_DB"
	envLagoRedisStorePassword                    = "LAGO_REDIS_STORE_PASSWORD"
	envLagoRedisStoreURL                         = "LAGO_REDIS_STORE_URL"
	envLagoRedisStoreTLS                         = "LAGO_REDIS_STORE_TLS"
)

type Config struct {
	Logger       *slog.Logger
	UseTelemetry bool
}

func initProducer(ctx context.Context, topicEnv string) (*kafka.Producer, error) {
	if os.Getenv(topicEnv) == "" {
		return nil, fmt.Errorf("%s variable is required", topicEnv)
	}

	topic := os.Getenv(topicEnv)
	producer, err := kafka.NewProducer(
		kafkaConfig,
		&kafka.ProducerConfig{
			Topic: topic,
		})
	if err != nil {
		return nil, err
	}

	err = producer.Ping(ctx)
	if err != nil {
		return nil, err
	}

	return producer, nil
}

func initFlagStore(ctx context.Context, name string) (*models.FlagStore, error) {
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

func initChargeCacheStore(ctx context.Context) (*models.ChargeCache, error) {
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

func StartProcessingEvents(ctx context.Context, config *Config) {
	serverBrokers := utils.ParseBrokersEnv(os.Getenv(envLagoKafkaBootstrapServers))
	if len(serverBrokers) == 0 {
		config.Logger.Error("brokers not found")
		panic("brokers not found")
	}

	kafkaConfig = kafka.ServerConfig{
		ScramAlgorithm: os.Getenv(envLagoKafkaScramAlgorithm),
		TLS:            utils.GetEnvAsBool(envLagoKafkaTLS, false),
		Servers:        serverBrokers,
		UseTelemetry:   config.UseTelemetry,
		UserName:       os.Getenv(envLagoKafkaUsername),
		Password:       os.Getenv(envLagoKafkaPassword),
	}

	eventsEnrichedProducer, err := initProducer(ctx, envLagoKafkaEnrichedEventsTopic)
	if err != nil {
		utils.LogAndPanic(config.Logger, err, "failed to initialize enriched events producer")
	}

	eventsEnrichedExpandedProducer, err := initProducer(ctx, envLagoKafkaEnrichedEventsExpandedTopic)
	if err != nil {
		utils.LogAndPanic(config.Logger, err, "failed to initialize enriched events expanded producer")
	}

	eventsInAdvanceProducer, err := initProducer(ctx, envLagoKafkaEventsChargedInAdvanceTopic)
	if err != nil {
		utils.LogAndPanic(config.Logger, err, "failed to initialize events charged in advance producer")
	}

	eventsDeadLetterQueue, err := initProducer(ctx, envLagoKafkaEventsDeadLetterTopic)
	if err != nil {
		utils.LogAndPanic(config.Logger, err, "failed to initialize events dead letter queue producer")
	}

	maxConns, err := utils.GetEnvAsInt(envLagoEventsProcessorDatabaseMaxConnections, 200)
	if err != nil {
		utils.LogAndPanic(config.Logger, err, "Error converting max connections into integer")
	}

	dbConfig := database.DBConfig{
		Url:      os.Getenv("DATABASE_URL"),
		MaxConns: int32(maxConns),
	}

	db, err := database.NewConnection(dbConfig)
	if err != nil {
		utils.LogAndPanic(config.Logger, err, "Error connecting to the database")
	}
	apiStore = models.NewApiStore(db)
	defer db.Close()

	flagger, err := initFlagStore(ctx, "subscription_refreshed")
	if err != nil {
		utils.LogAndPanic(config.Logger, err, "Error connecting to the flag store")
	}
	defer flagger.Close()

	cacher, err := initChargeCacheStore(ctx)
	if err != nil {
		utils.LogAndPanic(config.Logger, err, "Error connecting to the charge cache store")
	}
	chargeCacheStore = cacher
	defer chargeCacheStore.CacheStore.Close()

	processor = events_processor.NewEventProcessor(
		config.Logger,
		events_processor.NewEventEnrichmentService(apiStore),
		events_processor.NewEventProducerService(
			eventsEnrichedProducer,
			eventsEnrichedExpandedProducer,
			eventsInAdvanceProducer,
			eventsDeadLetterQueue,
			config.Logger,
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
		utils.LogAndPanic(config.Logger, err, "Error starting the event consumer")
	}

	config.Logger.Info("Starting event consumer")
	cg.Start(ctx)
	config.Logger.Info("Event processor stopped")
}
