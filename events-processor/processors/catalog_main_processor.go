package processors

import (
	"context"
	"fmt"
	"log/slog"
	"os"

	"github.com/twmb/franz-go/pkg/kgo"

	"github.com/getlago/lago/events-processor/config/kafka"
	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/processors/catalog_processor"
	"github.com/getlago/lago/events-processor/utils"
)

// StartProcessingCatalogEvents runs the catalog pipeline: it consumes the events
// of product catalog organizations and never touches the subscription pipeline's
// topics, tables or refresh flags.
func StartProcessingCatalogEvents(ctx context.Context, config *Config) {
	if os.Getenv(envLagoKafkaCatalogRawEventsTopic) == "" {
		utils.LogAndPanic(fmt.Errorf("%s variable is required", envLagoKafkaCatalogRawEventsTopic), "catalog raw events topic is missing")
	}

	initKafkaConfig(config.TracerProvider)

	enrichedProducer, err := initProducer(ctx, envLagoKafkaCatalogEnrichedEventsTopic)
	if err != nil {
		utils.LogAndPanic(err, "failed to initialize catalog enriched events producer")
	}

	inAdvanceProducer, err := initProducer(ctx, envLagoKafkaEventsChargedInAdvanceTopic)
	if err != nil {
		utils.LogAndPanic(err, "failed to initialize events charged in advance producer")
	}

	deadLetterQueue, err := initProducer(ctx, envLagoKafkaEventsDeadLetterTopic)
	if err != nil {
		utils.LogAndPanic(err, "failed to initialize events dead letter queue producer")
	}

	var catalogApiStore *models.ApiStore
	if config.Cache == nil {
		var closeDB func()
		catalogApiStore, closeDB = initApiStore()
		defer closeDB()
	}

	catalogProcessor := catalog_processor.NewCatalogProcessor(
		catalog_processor.NewEnrichmentService(catalogApiStore, config.Cache),
		catalog_processor.NewProducerService(enrichedProducer, inAdvanceProducer, deadLetterQueue),
	)

	// The consumer group name includes the topic, so LAGO_KAFKA_CONSUMER_GROUP can
	// be shared with the subscription pipeline.
	cg, err := kafka.NewConsumerGroup(
		kafkaConfig,
		&kafka.ConsumerGroupConfig{
			Topic:         os.Getenv(envLagoKafkaCatalogRawEventsTopic),
			ConsumerGroup: os.Getenv(envLagoKafkaConsumerGroup),
			ProcessRecords: func(ctx context.Context, records []*kgo.Record) []*kgo.Record {
				return catalogProcessor.ProcessEvents(ctx, records)
			},
		})
	if err != nil {
		utils.LogAndPanic(err, "Error starting the catalog event consumer")
	}

	slog.Info("Starting catalog event consumer")
	cg.Start(ctx)
	slog.Info("Catalog event processor stopped")
}
