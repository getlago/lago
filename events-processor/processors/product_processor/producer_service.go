package product_processor

import (
	"context"
	"fmt"
	"log/slog"

	"github.com/getlago/lago/events-processor/config/kafka"
	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/processors/pipeline"
	"github.com/getlago/lago/events-processor/utils"
)

type ProducerService struct {
	enrichedProducer kafka.MessageProducer
	producer         pipeline.Producer[models.ProductEvent]
}

func NewProducerService(enrichedProducer, deadLetterProducer kafka.MessageProducer) *ProducerService {
	return &ProducerService{
		enrichedProducer: enrichedProducer,
		producer:         pipeline.NewProducer[models.ProductEvent](deadLetterProducer),
	}
}

func (ps *ProducerService) ProduceEnrichedEvent(ctx context.Context, event *models.ProductEnrichedEvent) {
	msgKey := fmt.Sprintf("%s-%s", event.OrganizationID, event.TransactionID)

	if err := ps.producer.Produce(ctx, event, event.InitialEvent, msgKey, ps.enrichedProducer); err != nil {
		slog.Error("error while marshaling product enriched events")
		utils.CaptureError(err)
	}
}

func (ps *ProducerService) ProduceToDeadLetterQueue(ctx context.Context, event models.ProductEvent, errorResult utils.AnyResult) {
	ps.producer.ProduceToDeadLetterQueue(ctx, event, errorResult)
}
