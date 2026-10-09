package processors

import (
	"context"
	"fmt"
	"log/slog"
	"os"

	"github.com/twmb/franz-go/pkg/kgo"

	"github.com/getlago/lago/events-processor/config/kafka"
	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/processors/product_processor"
	"github.com/getlago/lago/events-processor/utils"
)

// StartProcessingProductEvents runs the product events pipeline: it consumes the events
// of product catalog organizations and never touches the subscription pipeline's
// topics, tables or refresh flags.
func StartProcessingProductEvents(ctx context.Context, config *Config) {
	if os.Getenv(envLagoKafkaProductRawEventsTopic) == "" {
		utils.LogAndPanic(fmt.Errorf("%s variable is required", envLagoKafkaProductRawEventsTopic), "product raw events topic is missing")
	}

	initKafkaConfig(config.TracerProvider)

	enrichedProducer, err := initProducer(ctx, envLagoKafkaProductEnrichedEventsTopic)
	if err != nil {
		utils.LogAndPanic(err, "failed to initialize product enriched events producer")
	}

	deadLetterQueue, err := initProducer(ctx, envLagoKafkaEventsDeadLetterTopic)
	if err != nil {
		utils.LogAndPanic(err, "failed to initialize events dead letter queue producer")
	}

	var productApiStore *models.ApiStore
	if config.Cache == nil {
		var closeDB func()
		productApiStore, closeDB = initApiStore()
		defer closeDB()
	}

	productProcessor := product_processor.NewProductProcessor(
		product_processor.NewEnrichmentService(productApiStore, config.Cache),
		product_processor.NewProducerService(enrichedProducer, deadLetterQueue),
	)

	// The consumer group name includes the topic, so LAGO_KAFKA_CONSUMER_GROUP can
	// be shared with the subscription pipeline.
	cg, err := kafka.NewConsumerGroup(
		kafkaConfig,
		&kafka.ConsumerGroupConfig{
			Topic:         os.Getenv(envLagoKafkaProductRawEventsTopic),
			ConsumerGroup: os.Getenv(envLagoKafkaConsumerGroup),
			ProcessRecords: func(ctx context.Context, records []*kgo.Record) []*kgo.Record {
				return productProcessor.ProcessEvents(ctx, records)
			},
		})
	if err != nil {
		utils.LogAndPanic(err, "Error starting the product event consumer")
	}

	slog.Info("Starting product event consumer")
	cg.Start(ctx)
	slog.Info("Product event processor stopped")
}
