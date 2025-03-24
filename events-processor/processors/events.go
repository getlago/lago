package processors

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"sync"
	"time"

	"github.com/getlago/lago-expression/expression-go"
	"github.com/twmb/franz-go/pkg/kgo"
	"go.opentelemetry.io/otel/attribute"

	tracer "github.com/getlago/lago/events-processor/config"
	"github.com/getlago/lago/events-processor/config/kafka"
	"github.com/getlago/lago/events-processor/models"
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

	for _, record := range records {
		go func(record *kgo.Record) {
			defer wg.Done()

			sp := tracer.GetTracerSpan(ctx, "post_process", "PostProcess.ProcessOneEvent")
			defer sp.End()

			event := models.Event{}
			err := json.Unmarshal(record.Value, &event)
			if err != nil {
				logger.Error("Error unmarshalling message", slog.String("error", err.Error()))
				return
			}

			result := processEvent(&event)
			if result.Failure() {
				logger.Error(
					result.ErrorMessage(),
					slog.String("error_code", result.ErrorCode()),
					slog.String("error", result.ErrorMsg()),
				)

				if result.ErrorDetails().Capture {
					utils.CaptureErrorResultWithExtra(result, "event", event)
				}

				go produceToDeadLetterQueue(event, result)
			}
		}(record)
	}

	wg.Wait()

	return records
}

func processEvent(event *models.Event) utils.Result[*models.EnrichedEvent] {
	enrichedEventResult := event.ToEnrichedEvent()
	if enrichedEventResult.Failure() {
		return failedResult(enrichedEventResult, "build_enriched_event", "Error while converting event to enriched event")
	}
	enrichedEvent := enrichedEventResult.Value()

	bmResult := apiStore.FetchBillableMetric(event.OrganizationID, event.Code)
	if bmResult.Failure() {
		return failedResultWithOptionalCapture(
			bmResult,
			"fetch_billable_metric",
			"Error fetching billable metric",
			bmResult.ErrorMsg() != models.ERROR_NOT_FOUND,
		)
	}
	bm := bmResult.Value()

	subResult := apiStore.FetchSubscription(event.OrganizationID, event.ExternalSubscriptionID, enrichedEvent.Time)
	if subResult.Failure() {
		return failedResultWithOptionalCapture(
			subResult,
			"fetch_subscription",
			"Error fetching subscription",
			subResult.ErrorMsg() != models.ERROR_NOT_FOUND,
		)
	}
	sub := subResult.Value()

	if event.Source != models.HTTP_RUBY {
		expressionResult := evaluateExpression(enrichedEvent, bm)
		if expressionResult.Failure() {
			return failedResult(expressionResult, "evaluate_expression", "Error evaluating custom expression")
		}
	}

	var value = fmt.Sprintf("%v", event.Properties[bm.FieldName])
	enrichedEvent.Value = &value

	go produceEnrichedEvent(enrichedEvent)

	if event.ShouldCheckInAdvanceBilling() {
		hasInAdvanceChargeResult := apiStore.AnyInAdvanceCharge(sub.PlanID, bm.ID)
		if hasInAdvanceChargeResult.Failure() {
			return failedResult(hasInAdvanceChargeResult, "fetch_in_advance_charges", "Error fetching in advance charges")
		}

		if hasInAdvanceChargeResult.Value() {
			go produceChargedInAdvanceEvent(enrichedEvent)
		}
	}

	return utils.SuccessResult(enrichedEvent)
}

func failedResult(r utils.AnyResult, code string, message string) utils.Result[*models.EnrichedEvent] {
	return utils.FailedResult[*models.EnrichedEvent](r.Error()).AddErrorDetails(code, message, true)
}

func failedResultWithOptionalCapture(r utils.AnyResult, code string, message string, capture bool) utils.Result[*models.EnrichedEvent] {
	return utils.FailedResult[*models.EnrichedEvent](r.Error()).AddErrorDetails(code, message, capture)
}

func evaluateExpression(ev *models.EnrichedEvent, bm *models.BillableMetric) utils.Result[bool] {
	if bm.Expression == "" {
		return utils.SuccessResult(false)
	}

	eventJson, err := json.Marshal(ev)
	if err != nil {
		return utils.FailedBoolResult(err)
	}
	eventJsonString := string(eventJson[:])

	result := expression.Evaluate(bm.Expression, eventJsonString)
	if result != nil {
		ev.Properties[bm.FieldName] = *result
	} else {
		return utils.FailedBoolResult(fmt.Errorf("Failed to evaluate expr: %s with json: %s", bm.Expression, eventJsonString))
	}

	return utils.SuccessResult(true)
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
	}

	pushed := eventsDeadLetterQueue.Produce(ctx, &kafka.ProducerMessage{
		Value: eventJson,
	})

	if !pushed {
		logger.Error("error while pushing to dead letter topic", slog.String("topic", eventsDeadLetterQueue.GetTopic()))
		utils.CaptureErrorResultWithExtra(errorResult, "event", event)
	}
}
