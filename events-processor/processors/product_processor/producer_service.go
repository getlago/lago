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
	enrichedProducer  kafka.MessageProducer
	inAdvanceProducer kafka.MessageProducer
	producer          pipeline.Producer[models.ProductEvent]
}

// NewProducerService takes a nil inAdvanceProducer when the in advance topic is not
// configured: the pipeline then charges nothing in advance.
func NewProducerService(enrichedProducer, inAdvanceProducer, deadLetterProducer kafka.MessageProducer) *ProducerService {
	return &ProducerService{
		enrichedProducer:  enrichedProducer,
		inAdvanceProducer: inAdvanceProducer,
		producer:          pipeline.NewProducer[models.ProductEvent](deadLetterProducer),
	}
}

func (ps *ProducerService) ProduceEnrichedEvent(ctx context.Context, event *models.ProductEnrichedEvent) {
	ps.produce(ctx, event, ps.enrichedProducer, "error while marshaling product enriched events")
}

func (ps *ProducerService) ChargesInAdvance() bool {
	return ps.inAdvanceProducer != nil
}

func (ps *ProducerService) ProduceChargedInAdvanceEvent(ctx context.Context, event *models.ProductEnrichedEvent) {
	ps.produce(ctx, event, ps.inAdvanceProducer, "error while marshaling product events charged in advance")
}

func (ps *ProducerService) ProduceToDeadLetterQueue(ctx context.Context, event models.ProductEvent, errorResult utils.AnyResult) {
	ps.producer.ProduceToDeadLetterQueue(ctx, event, errorResult)
}

func (ps *ProducerService) produce(ctx context.Context, event *models.ProductEnrichedEvent, target kafka.MessageProducer, errorMessage string) {
	msgKey := fmt.Sprintf("%s-%s", event.OrganizationID, event.TransactionID)

	if err := ps.producer.Produce(ctx, event, event.InitialEvent, msgKey, target); err != nil {
		slog.Error(errorMessage)
		utils.CaptureError(err)
	}
}
