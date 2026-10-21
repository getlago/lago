package catalog_processor

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
	enrichedProducer  kafka.MessageProducer
	inAdvanceProducer kafka.MessageProducer
	producer          pipeline.Producer
}

func NewProducerService(enrichedProducer, inAdvanceProducer, deadLetterProducer kafka.MessageProducer) *ProducerService {
	return &ProducerService{
		enrichedProducer:  enrichedProducer,
		inAdvanceProducer: inAdvanceProducer,
		producer:          pipeline.NewProducer(deadLetterProducer),
	}
}

func (ps *ProducerService) ProduceEnrichedEvent(ctx context.Context, event *models.CatalogEnrichedEvent) {
	msgKey := fmt.Sprintf("%s-%s", event.OrganizationID, event.TransactionID)

	if err := ps.producer.Produce(ctx, event, event.InitialEvent, msgKey, ps.enrichedProducer); err != nil {
		slog.Error("error while marshaling catalog enriched events")
		utils.CaptureError(err)
	}
}

func (ps *ProducerService) ProduceChargedInAdvanceEvent(ctx context.Context, event *models.EnrichedEvent) {
	msgKey := fmt.Sprintf("%s-%s", event.OrganizationID, event.TransactionID)

	if err := ps.producer.Produce(ctx, event, event.InitialEvent, msgKey, ps.inAdvanceProducer); err != nil {
		slog.Error("error while marshaling charged in advance events")
		utils.CaptureError(err)
	}
}

func (ps *ProducerService) ProduceToDeadLetterQueue(ctx context.Context, event models.Event, errorResult utils.AnyResult) {
	ps.producer.ProduceToDeadLetterQueue(ctx, event, errorResult)
}
