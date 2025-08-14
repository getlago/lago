package event_processors

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"sort"
	"time"

	"github.com/getlago/lago/events-processor/config/kafka"
	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/utils"
)

type EventProducerService struct {
	enrichedProducer         kafka.MessageProducer
	enrichedExpendedProducer kafka.MessageProducer
	inAdvanceProducer        kafka.MessageProducer
	deadLetterProducer       kafka.MessageProducer
	logger                   *slog.Logger
}

func NewEventProducerService(enrichedProducer, enrichedExpendedProducer, inAdvanceProducer, deadLetterProducer kafka.MessageProducer, logger *slog.Logger) *EventProducerService {
	return &EventProducerService{
		enrichedProducer:         enrichedProducer,
		enrichedExpendedProducer: enrichedExpendedProducer,
		inAdvanceProducer:        inAdvanceProducer,
		deadLetterProducer:       deadLetterProducer,
		logger:                   logger,
	}
}

func (eps *EventProducerService) ProduceEnrichedEvent(context context.Context, event *models.EnrichedEvent) {
	msgKey := fmt.Sprintf("%s-%s-%s", event.OrganizationID, event.ExternalSubscriptionID, event.Code)

	err := eps.produceEvent(context, event, msgKey, eps.enrichedProducer)

	if err != nil {
		eps.logger.Error("error while marshaling enriched events")
		utils.CaptureError(err)
	}
}

func (eps *EventProducerService) ProduceEnrichedExpendedEvent(context context.Context, event *models.EnrichedEvent) {
	chargeID := ""
	if event.ChargeID != nil {
		chargeID = *event.ChargeID
	}

	chargeFilterID := ""
	if event.ChargeFilterID != nil {
		chargeFilterID = *event.ChargeFilterID
	}

	groupedBy := ""
	groupKeys := make([]string, 0, len(event.GroupedBy))
	for key := range event.GroupedBy {
		groupKeys = append(groupKeys, key)
	}
	sort.Strings(groupKeys)

	for _, key := range groupKeys {
		if groupedBy != "" {
			groupedBy += "|"
		}
		groupedBy += fmt.Sprintf("%s/%s", key, event.GroupedBy[key])
	}

	msgKey := fmt.Sprintf("%s-%s-%s-%s-%s-%s", event.OrganizationID, event.ExternalSubscriptionID, event.Code, chargeID, chargeFilterID, groupedBy)

	err := eps.produceEvent(context, event, msgKey, eps.enrichedExpendedProducer)
	if err != nil {
		eps.logger.Error("error while marshaling enriched expended events")
		utils.CaptureError(err)
	}
}

func (eps *EventProducerService) ProduceChargedInAdvanceEvent(context context.Context, event *models.EnrichedEvent) {
	msgKey := fmt.Sprintf("%s-%s-%s", event.OrganizationID, event.ExternalSubscriptionID, event.Code)

	err := eps.produceEvent(context, event, msgKey, eps.inAdvanceProducer)

	if err != nil {
		eps.logger.Error("error while marshaling charged in advance events")
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
		eps.logger.Error("error while marshaling failed event with error details")
		utils.CaptureError(err)
	}

	pushed := eps.deadLetterProducer.Produce(context, &kafka.ProducerMessage{
		Value: eventJson,
	})

	if !pushed {
		eps.logger.Error("error while pushing to dead letter topic", slog.String("topic", eps.deadLetterProducer.GetTopic()))
		utils.CaptureErrorResultWithExtra(errorResult, "event", event)
	}
}

func (eps *EventProducerService) produceEvent(context context.Context, event *models.EnrichedEvent, msgKey string, producer kafka.MessageProducer) error {
	eventJson, err := json.Marshal(event)
	if err != nil {
		return err
	}

	pushed := producer.Produce(context, &kafka.ProducerMessage{
		Key:   []byte(msgKey),
		Value: eventJson,
	})

	if !pushed {
		eps.ProduceToDeadLetterQueue(context, *event.InitialEvent, utils.FailedBoolResult(fmt.Errorf("Failed to push to %s topic", producer.GetTopic())))
	}

	return nil
}
