package events_processor

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"time"

	"github.com/getlago/lago/events-processor/config/kafka"
	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/utils"
)

type EventProducerService struct {
	enrichedProducer        kafka.MessageProducer
	inAdvanceProducer       kafka.MessageProducer
	deadLetterProducer      kafka.MessageProducer
	catalogEnrichedProducer kafka.MessageProducer
}

func NewEventProducerService(enrichedProducer, inAdvanceProducer, deadLetterProducer kafka.MessageProducer) *EventProducerService {
	return &EventProducerService{
		enrichedProducer:   enrichedProducer,
		inAdvanceProducer:  inAdvanceProducer,
		deadLetterProducer: deadLetterProducer,
	}
}

// WithCatalogEnrichedProducer sets the producer of the catalog pipeline, only
// configured when the catalog raw topic is consumed.
func (eps *EventProducerService) WithCatalogEnrichedProducer(producer kafka.MessageProducer) *EventProducerService {
	eps.catalogEnrichedProducer = producer
	return eps
}

func (eps *EventProducerService) ProduceEnrichedEvent(context context.Context, event *models.EnrichedEvent) {
	msgKey := fmt.Sprintf("%s-%s", event.OrganizationID, event.TransactionID)

	err := eps.produceEvent(context, event, event.InitialEvent, msgKey, eps.enrichedProducer)

	if err != nil {
		slog.Error("error while marshaling enriched events")
		utils.CaptureError(err)
	}
}

func (eps *EventProducerService) ProduceCatalogEnrichedEvent(context context.Context, event *models.CatalogEnrichedEvent) {
	msgKey := fmt.Sprintf("%s-%s", event.OrganizationID, event.TransactionID)

	err := eps.produceEvent(context, event, event.InitialEvent, msgKey, eps.catalogEnrichedProducer)

	if err != nil {
		slog.Error("error while marshaling catalog enriched events")
		utils.CaptureError(err)
	}
}

func (eps *EventProducerService) ProduceChargedInAdvanceEvent(context context.Context, event *models.EnrichedEvent) {
	msgKey := fmt.Sprintf("%s-%s", event.OrganizationID, event.TransactionID)

	err := eps.produceEvent(context, event, event.InitialEvent, msgKey, eps.inAdvanceProducer)

	if err != nil {
		slog.Error("error while marshaling charged in advance events")
		utils.CaptureError(err)
	}
}

func (eps *EventProducerService) ProduceToDeadLetterQueue(context context.Context, event models.Event, errorResult utils.AnyResult) {
	failedEvent := models.FailedEvent{
		Event:               event,
		InitialErrorMessage: errorResult.ErrorMsg(),
		ErrorCode:           errorResult.ErrorCode(),
		ErrorMessage:        errorResult.ErrorMessage(),
		FailedAt:            time.Now(),
	}

	eventJson, err := json.Marshal(failedEvent)
	if err != nil {
		slog.Error("error while marshaling failed event with error details")
		utils.CaptureError(err)
	}

	pushed := eps.deadLetterProducer.Produce(context, &kafka.ProducerMessage{
		Value: eventJson,
	})

	if !pushed {
		slog.Error("error while pushing to dead letter topic", slog.String("topic", eps.deadLetterProducer.GetTopic()))
		utils.CaptureErrorResultWithExtra(errorResult, "event", event)
	}
}

func (eps *EventProducerService) produceEvent(context context.Context, event any, initialEvent *models.Event, msgKey string, producer kafka.MessageProducer) error {
	eventJson, err := json.Marshal(event)
	if err != nil {
		return err
	}

	pushed := producer.Produce(context, &kafka.ProducerMessage{
		Key:   []byte(msgKey),
		Value: eventJson,
	})

	if !pushed {
		eps.ProduceToDeadLetterQueue(context, *initialEvent, utils.FailedBoolResult(fmt.Errorf("failed to push to %s topic", producer.GetTopic())))
	}

	return nil
}
