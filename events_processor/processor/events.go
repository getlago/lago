package processor

import (
	"encoding/json"
	"fmt"
	"log/slog"
	"sync"

	"github.com/getlago/lago/events-processor/processor/models"

	"github.com/getlago/lago-expression/expression-go"
	"github.com/getlago/lago/events-processor/config/kafka"
	"github.com/getlago/lago/events-processor/database"
	"github.com/getlago/lago/events-processor/utils"
	"github.com/twmb/franz-go/pkg/kgo"
)

func processEvents(records []*kgo.Record) []*kgo.Record {
	wg := sync.WaitGroup{}
	mu := sync.Mutex{}
	wg.Add(len(records))

	for _, record := range records {
		go func(record *kgo.Record) {
			defer wg.Done()

			event := models.Event{}
			err := json.Unmarshal(record.Value, &event)
			if err != nil {
				logger.Error("Error unmarshalling message", slog.String("error", err.Error()))
				return
			}

			if _, err := processEvent(&event); err != nil {
				// TODO: Do we need the mutex here?
				// 			 How to handle some auto retry?

				mu.Lock()
				produceToDeadLetterQueue(event, err)
				mu.Unlock()
			}
		}(record)
	}

	wg.Wait()

	// TODO: only return a status / offset, to allow commit
	return records
}

func processEvent(event *models.Event) (*models.Event, error) {
	bmResult := db.FetchBillableMetric(event.OrganizationID, event.Code)
	if bmResult.Failure() {
		logger.Error("Error fetching billable metric", slog.String("error", bmResult.ErrorMsg()))
		return nil, bmResult.Error()
	}
	bm := bmResult.Value()

	if event.Source != models.HTTP_RUBY {
		subResult := db.FetchSubscription(event.OrganizationID, event.ExternalSubscriptionID, event.TimestampAsTime())
		if subResult.Failure() {
			logger.Error("Error fetching subscription", slog.String("error", subResult.ErrorMsg()))
			return nil, subResult.Error()
		}
		sub := subResult.Value()

		expressionResult := evaluateExpression(event, bm)
		if expressionResult.Failure() {
			logger.Error("Error evaluating custom expression", slog.String("error", expressionResult.ErrorMsg()))
			return nil, expressionResult.Error()
		}

		hasInAdvanceChargeResult := db.AnyInAdvanceCharge(sub.PlanID, bm.ID)
		if hasInAdvanceChargeResult.Failure() {
			logger.Error("Error fetching in advance charges", slog.String("error", hasInAdvanceChargeResult.ErrorMsg()))
			return nil, hasInAdvanceChargeResult.Error()
		}

		if hasInAdvanceChargeResult.Value() {
			go produceChargedInAdvanceEvent(event)
		}
	}

	var value = fmt.Sprintf("%v", event.Properties[bm.FieldName])
	event.Value = &value
	go produceEnrichedEvent(event)

	return event, nil
}

func evaluateExpression(ev *models.Event, bm *database.BillableMetric) utils.Result[bool] {
	if bm.Expression == "" {
		return utils.SuccessResult(false)
	}

	eventJson, err := json.Marshal(ev)
	if err != nil {
		logger.Error("error while marshaling events")
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
		logger.Error("error while marshaling enriched events")
	}

	msgKey := fmt.Sprintf("%s-%s-%s", ev.OrganizationID, ev.ExternalSubscriptionID, ev.Code)

	// TODO: how to ensure message has been produced?
	eventsInAdvanceProducer.Produce(ctx, &kafka.ProducerMessage{
		Key:   []byte(msgKey),
		Value: eventJson,
	})
}

func produceToDeadLetterQueue(event models.Event, err error) {
	failedEvent := models.FailedEvent{
		Event:        event,
		ErrorMessage: err.Error(),
	}

	eventJson, err := json.Marshal(failedEvent)
	if err != nil {
		logger.Error("error while marshaling failed events")
	}

	eventsDeadLetterQueue.Produce(ctx, &kafka.ProducerMessage{
		Value: eventJson,
	})
}
