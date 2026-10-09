package events_processor

import (
	"context"
	"fmt"
	"log/slog"

	"github.com/getlago/lago/events-processor/config/kafka"
	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/processors/pipeline"
	"github.com/getlago/lago/events-processor/utils"
)

type EventProducerService struct {
	enrichedProducer  kafka.MessageProducer
	inAdvanceProducer kafka.MessageProducer
	producer          pipeline.Producer
}

func NewEventProducerService(enrichedProducer, inAdvanceProducer, deadLetterProducer kafka.MessageProducer) *EventProducerService {
	return &EventProducerService{
		enrichedProducer:  enrichedProducer,
		inAdvanceProducer: inAdvanceProducer,
		producer:          pipeline.NewProducer(deadLetterProducer),
	}
}

func (eps *EventProducerService) ProduceEnrichedEvent(context context.Context, event *models.EnrichedEvent) {
	msgKey := fmt.Sprintf("%s-%s", event.OrganizationID, event.TransactionID)

	err := eps.produceEvent(context, event, msgKey, eps.enrichedProducer)

	if err != nil {
		slog.Error("error while marshaling enriched events")
		utils.CaptureError(err)
	}
}

func (eps *EventProducerService) ProduceChargedInAdvanceEvent(context context.Context, event *models.EnrichedEvent) {
	msgKey := fmt.Sprintf("%s-%s", event.OrganizationID, event.TransactionID)

	err := eps.produceEvent(context, event, msgKey, eps.inAdvanceProducer)

	if err != nil {
		slog.Error("error while marshaling charged in advance events")
		utils.CaptureError(err)
	}
}

func (eps *EventProducerService) ProduceToDeadLetterQueue(context context.Context, event models.Event, errorResult utils.AnyResult) {
	eps.producer.ProduceToDeadLetterQueue(context, event, errorResult)
}

func (eps *EventProducerService) produceEvent(context context.Context, event *models.EnrichedEvent, msgKey string, producer kafka.MessageProducer) error {
	return eps.producer.Produce(context, event, event.InitialEvent, msgKey, producer)
}
