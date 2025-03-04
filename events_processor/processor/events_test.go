package processor

import (
	"context"
	"encoding/json"
	"fmt"
	"testing"

	"github.com/stretchr/testify/assert"

	"github.com/getlago/lago/events-processor/config/kafka"
	"github.com/getlago/lago/events-processor/database"
	"github.com/getlago/lago/events-processor/processor/models"
	"github.com/getlago/lago/events-processor/utils"
)

func TestEvaluateExpression(t *testing.T) {
	bm := database.BillableMetric{}
	event := models.Event{Timestamp: 1741007009}

	// Without expression
	result := evaluateExpression(&event, &bm)
	assert.True(t, result.Success(), "It should succeed when Billable metric does not have a custom expression")

	// With an expression but witout required fields
	bm.Expression = "round(event.properties.value * event.properties.units)"
	bm.FieldName = "total_value"
	result = evaluateExpression(&event, &bm)
	assert.False(t, result.Success())
	assert.Contains(
		t,
		result.ErrorMsg(),
		"Failed to evaluate expr:",
		"It should fail when the event does not hold the required fields",
	)

	// With an expression and with required fields
	properties := map[string]any{
		"value": "12.0",
		"units": 3,
	}
	event.Properties = properties
	result = evaluateExpression(&event, &bm)
	assert.True(t, result.Success())
	assert.Equal(t, "36", event.Properties["total_value"])
}

// Definition of the mocked message producer
type mockMessageProducer struct {
	key            []byte
	value          []byte
	executionCount int
}

func (mp *mockMessageProducer) Produce(ctx context.Context, msg *kafka.ProducerMessage) bool {
	mp.key = msg.Key
	mp.value = msg.Value
	mp.executionCount++
	return true
}

func TestProduceEnrichedEvent(t *testing.T) {
	producer := mockMessageProducer{}
	eventsEnrichedProducer = &producer
	ctx = context.Background()

	event := models.Event{
		OrganizationID:         "1a901a90-1a90-1a90-1a90-1a901a901a90",
		ExternalSubscriptionID: "sub_id",
		Code:                   "api_calls",
	}

	produceEnrichedEvent(&event)

	assert.Equal(t, 1, producer.executionCount)
	assert.Equal(
		t,
		[]byte("1a901a90-1a90-1a90-1a90-1a901a901a90-sub_id-api_calls"),
		producer.key,
	)

	eventJson, _ := json.Marshal(event)
	assert.Equal(t, eventJson, producer.value)
}

func TestProduceChargedInAdvanceEvent(t *testing.T) {
	producer := mockMessageProducer{}
	eventsInAdvanceProducer = &producer
	ctx = context.Background()

	event := models.Event{
		OrganizationID:         "1a901a90-1a90-1a90-1a90-1a901a901a90",
		ExternalSubscriptionID: "sub_id",
		Code:                   "api_calls",
	}

	produceChargedInAdvanceEvent(&event)

	assert.Equal(t, 1, producer.executionCount)
	assert.Equal(
		t,
		[]byte("1a901a90-1a90-1a90-1a90-1a901a901a90-sub_id-api_calls"),
		producer.key,
	)

	eventJson, _ := json.Marshal(event)
	assert.Equal(t, eventJson, producer.value)
}

func TestProduceToDeadLetterQueue(t *testing.T) {
	producer := mockMessageProducer{}
	eventsDeadLetterQueue = &producer
	ctx = context.Background()

	event := models.Event{
		OrganizationID:         "1a901a90-1a90-1a90-1a90-1a901a901a90",
		ExternalSubscriptionID: "sub_id",
		Code:                   "api_calls",
	}

	result := utils.FailedResult[string](fmt.Errorf("Error Message"))
	failedEvent := models.FailedEvent{
		Event:               event,
		InitialErrorMessage: "Error Message",
		ErrorCode:           "",
		ErrorMessage:        "",
	}

	produceToDeadLetterQueue(event, result)

	assert.Equal(t, 1, producer.executionCount)

	eventJson, _ := json.Marshal(failedEvent)
	assert.Equal(t, eventJson, producer.value)
}
