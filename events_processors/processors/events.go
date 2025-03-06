package processors

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"sync"

	"github.com/getlago/lago-expression/expression-go"
	"github.com/twmb/franz-go/pkg/kgo"
	"go.opentelemetry.io/otel/attribute"

	tracer "github.com/getlago/lago/events-processors/config"
	"github.com/getlago/lago/events-processors/config/kafka"
	"github.com/getlago/lago/events-processors/models"
	"github.com/getlago/lago/events-processors/utils"
)

func processEvents(records []*kgo.Record) []*kgo.Record {
	ctx := context.Background()
	span := tracer.GetTracerSpan(ctx, "post_process", "PostProcess.ProcessEvents")
	recordsAttr := attribute.Int("records.length", len(records))
	span.SetAttributes(recordsAttr)
	defer span.End()

	wg := sync.WaitGroup{}
	mu := sync.Mutex{}
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

				mu.Lock()
				produceToDeadLetterQueue(event, result)
				mu.Unlock()
			}
		}(record)
	}

	wg.Wait()

	return records
}

func processEvent(event *models.Event) utils.AnyResult {
	bmResult := apiStore.FetchBillableMetric(event.OrganizationID, event.Code)
	if bmResult.Failure() {
		return bmResult.AddErrorDetails("fetch_billable_metric", "Error fetching billable metric")
	}
	bm := bmResult.Value()

	if event.Source != models.HTTP_RUBY {
		timestampResult := event.TimestampAsTime()
		if timestampResult.Failure() {
			return timestampResult.AddErrorDetails("parse_timestamp", "Error parsing event timestamp")
		}

		subResult := apiStore.FetchSubscription(event.OrganizationID, event.ExternalSubscriptionID, timestampResult.Value())
		if subResult.Failure() {
			return subResult.AddErrorDetails("fetch_subscription", "Error fetching subscription")
		}
		sub := subResult.Value()

		expressionResult := evaluateExpression(event, bm)
		if expressionResult.Failure() {
			return expressionResult.AddErrorDetails("evaluate_expressionh", "Error evaluating custom expression")
		}

		hasInAdvanceChargeResult := apiStore.AnyInAdvanceCharge(sub.PlanID, bm.ID)
		if hasInAdvanceChargeResult.Failure() {
			return hasInAdvanceChargeResult.AddErrorDetails("fetch_in_advance_charges", "Error fetching in advance charges")
		}

		if hasInAdvanceChargeResult.Value() {
			go produceChargedInAdvanceEvent(event)
		}
	}

	var value = fmt.Sprintf("%v", event.Properties[bm.FieldName])
	event.Value = &value
	go produceEnrichedEvent(event)

	return utils.SuccessResult(event)
}

func evaluateExpression(ev *models.Event, bm *models.BillableMetric) utils.Result[bool] {
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

func produceEnrichedEvent(ev *models.Event) {
	eventJson, err := json.Marshal(ev)
	if err != nil {
		logger.Error("error while marshaling enriched events")
	}

	msgKey := fmt.Sprintf("%s-%s-%s", ev.OrganizationID, ev.ExternalSubscriptionID, ev.Code)

	// TODO: how to ensure message has been produced?
	eventsEnrichedProducer.Produce(ctx, &kafka.ProducerMessage{
		Key:   []byte(msgKey),
		Value: eventJson,
	})
}

func produceChargedInAdvanceEvent(ev *models.Event) {
	eventJson, err := json.Marshal(ev)
	if err != nil {
		logger.Error("error while marshaling charged in advance events")
	}

	msgKey := fmt.Sprintf("%s-%s-%s", ev.OrganizationID, ev.ExternalSubscriptionID, ev.Code)

	// TODO: how to ensure message has been produced?
	eventsInAdvanceProducer.Produce(ctx, &kafka.ProducerMessage{
		Key:   []byte(msgKey),
		Value: eventJson,
	})
}

func produceToDeadLetterQueue(event models.Event, errorResult utils.AnyResult) {
	failedEvent := models.FailedEvent{
		Event:               event,
		InitialErrorMessage: errorResult.ErrorMsg(),
		ErrorCode:           errorResult.ErrorCode(),
		ErrorMessage:        errorResult.ErrorMessage(),
	}

	eventJson, err := json.Marshal(failedEvent)
	if err != nil {
		logger.Error("error while marshaling failed event with error details")
	}

	eventsDeadLetterQueue.Produce(ctx, &kafka.ProducerMessage{
		Value: eventJson,
	})
}
