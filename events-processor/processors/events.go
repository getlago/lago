package processors

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"sync"
	"time"

	"github.com/twmb/franz-go/pkg/kgo"
	"go.opentelemetry.io/otel/attribute"

	tracer "github.com/getlago/lago/events-processor/config"
	"github.com/getlago/lago/events-processor/config/kafka"
	"github.com/getlago/lago/events-processor/models"
	events "github.com/getlago/lago/events-processor/processors/event_processors"
	"github.com/getlago/lago/events-processor/utils"
)

func processEvents(records []*kgo.Record) []*kgo.Record {
	ctx := context.Background()
	span := tracer.GetTracerSpan(ctx, "post_process", "PostProcess.ProcessEvents")
	recordsAttr := attribute.Int("records.length", len(records))
	span.SetAttributes(recordsAttr)
	defer span.End()

	wg := sync.WaitGroup{}
	wg.Add(len(records))

	var mu sync.Mutex
	processedRecords := make([]*kgo.Record, 0)

	for _, record := range records {
		go func(record *kgo.Record) {
			defer wg.Done()

			sp := tracer.GetTracerSpan(ctx, "post_process", "PostProcess.ProcessOneEvent")
			defer sp.End()

			event := models.Event{}
			err := json.Unmarshal(record.Value, &event)
			if err != nil {
				logger.Error("Error unmarshalling message", slog.String("error", err.Error()))
				utils.CaptureError(err)

				mu.Lock()
				// If we fail to unmarshal the record, we should commit it as it will failed forever
				processedRecords = append(processedRecords, record)
				mu.Unlock()
				return
			}

			result := processEvent(&event)
			if result.Failure() {
				logger.Error(
					result.ErrorMessage(),
					slog.String("error_code", result.ErrorCode()),
					slog.String("error", result.ErrorMsg()),
				)

				if result.IsCapturable() {
					utils.CaptureErrorResultWithExtra(result, "event", event)
				}

				if result.IsRetryable() && time.Since(event.IngestedAt.Time()) < 12*time.Hour {
					// For retryable errors, we should avoid commiting the record,
					// It will be consumed again and reprocessed
					// Events older than 12 hours should also be pushed dead letter queue
					return
				}

				// Push failed records to the dead letter queue
				go produceToDeadLetterQueue(event, result)
			}

			// Track processed records
			mu.Lock()
			processedRecords = append(processedRecords, record)
			mu.Unlock()
		}(record)
	}

	wg.Wait()

	return processedRecords
}

func processEvent(event *models.Event) utils.Result[*models.EnrichedEvent] {
	eventEnrichmentService := events.NewEventEnrichmentService(apiStore)
	enrichedEventResult := eventEnrichmentService.EnrichEvent(event)
	if enrichedEventResult.Failure() {
		return failedResult(enrichedEventResult, enrichedEventResult.ErrorCode(), enrichedEventResult.ErrorMessage())
	}

	enrichedEvents := enrichedEventResult.Value()
	enrichedEvent := enrichedEvents[0] // TODO:Add full support for multiple enriched events

	go produceEnrichedEvent(enrichedEvent)

	if enrichedEvent.Subscription != nil && event.NotAPIPostProcessed() {
		hasInAdvanceChargeResult := apiStore.AnyInAdvanceCharge(enrichedEvent.PlanID, enrichedEvent.BillableMetric.ID)
		if hasInAdvanceChargeResult.Failure() {
			return failedResult(hasInAdvanceChargeResult, "fetch_in_advance_charges", "Error fetching in advance charges")
		}

		if hasInAdvanceChargeResult.Value() {
			go produceChargedInAdvanceEvent(enrichedEvent)
		}

		flagResult := flagSubscriptionRefresh(event.OrganizationID, enrichedEvent.Subscription)
		if flagResult.Failure() {
			return failedResult(flagResult, "flag_subscription_refresh", "Error flagging subscription refresh")
		}

		// Expire cache at charge and charge filter level
		cacheService := events.NewCacheService(chargeCacheStore)
		cacheService.ExpireCache(enrichedEvents)
	}

	return utils.SuccessResult(enrichedEvent)
}

func failedResult(r utils.AnyResult, code string, message string) utils.Result[*models.EnrichedEvent] {
	result := utils.FailedResult[*models.EnrichedEvent](r.Error()).AddErrorDetails(code, message)
	result.Retryable = r.IsRetryable()
	result.Capture = r.IsCapturable()
	return result
}

func produceEnrichedEvent(ev *models.EnrichedEvent) {
	eventJson, err := json.Marshal(ev)
	if err != nil {
		logger.Error("error while marshaling enriched events")
	}

	msgKey := fmt.Sprintf("%s-%s-%s", ev.OrganizationID, ev.ExternalSubscriptionID, ev.Code)

	pushed := eventsEnrichedProducer.Produce(ctx, &kafka.ProducerMessage{
		Key:   []byte(msgKey),
		Value: eventJson,
	})

	if !pushed {
		produceToDeadLetterQueue(*ev.IntialEvent, utils.FailedBoolResult(fmt.Errorf("Failed to push to %s topic", eventsEnrichedProducer.GetTopic())))
	}
}

func produceChargedInAdvanceEvent(ev *models.EnrichedEvent) {
	eventJson, err := json.Marshal(ev)
	if err != nil {
		logger.Error("error while marshaling charged in advance events")
		utils.CaptureError(err)
	}

	msgKey := fmt.Sprintf("%s-%s-%s", ev.OrganizationID, ev.ExternalSubscriptionID, ev.Code)

	pushed := eventsInAdvanceProducer.Produce(ctx, &kafka.ProducerMessage{
		Key:   []byte(msgKey),
		Value: eventJson,
	})

	if !pushed {
		produceToDeadLetterQueue(*ev.IntialEvent, utils.FailedBoolResult(fmt.Errorf("Failed to push to %s topic", eventsInAdvanceProducer.GetTopic())))
	}
}

func produceToDeadLetterQueue(event models.Event, errorResult utils.AnyResult) {
	failedEvent := models.FailedEvent{
		Event:               event,
		InitialErrorMessage: errorResult.ErrorMsg(),
		ErrorCode:           errorResult.ErrorCode(),
		ErrorMessage:        errorResult.ErrorMessage(),
		FailedAt:            time.Now(),
	}

	eventJson, err := json.Marshal(failedEvent)
	if err != nil {
		logger.Error("error while marshaling failed event with error details")
		utils.CaptureError(err)
	}

	pushed := eventsDeadLetterQueue.Produce(ctx, &kafka.ProducerMessage{
		Value: eventJson,
	})

	if !pushed {
		logger.Error("error while pushing to dead letter topic", slog.String("topic", eventsDeadLetterQueue.GetTopic()))
		utils.CaptureErrorResultWithExtra(errorResult, "event", event)
	}
}

func flagSubscriptionRefresh(orgID string, sub *models.Subscription) utils.Result[bool] {
	err := subscriptionFlagStore.Flag(fmt.Sprintf("%s:%s", orgID, sub.ID))
	if err != nil {
		return utils.FailedBoolResult(err)
	}

	return utils.SuccessResult(true)
}
