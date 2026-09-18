package events_processor

import (
	"context"
	"encoding/json"
	"fmt"
	"testing"
	"time"

	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/tests"
	"github.com/getlago/lago/events-processor/utils"
	"github.com/stretchr/testify/assert"
)

var (
	producerService    *EventProducerService
	enrichedProducer   *tests.MockMessageProducer
	inAdvanceProducer  *tests.MockMessageProducer
	deadLetterProducer *tests.MockMessageProducer
)

func setupProducerServiceEnv() {
	enrichedProducer = &tests.MockMessageProducer{}
	inAdvanceProducer = &tests.MockMessageProducer{}
	deadLetterProducer = &tests.MockMessageProducer{}

	producerService = NewEventProducerService(
		enrichedProducer,
		inAdvanceProducer,
		deadLetterProducer,
	)
}

func TestProduceEnrichedEvent(t *testing.T) {
	setupProducerServiceEnv()

	event := models.EnrichedEvent{
		OrganizationID:         "1a901a90-1a90-1a90-1a90-1a901a901a90",
		ExternalSubscriptionID: "sub_id",
		Code:                   "api_calls",
		TransactionID:          "transaction_id",
	}

	producerService.ProduceEnrichedEvent(context.Background(), &event)

	assert.Equal(t, 1, enrichedProducer.ExecutionCount)
	assert.Equal(
		t,
		[]byte("1a901a90-1a90-1a90-1a90-1a901a901a90-transaction_id"),
		enrichedProducer.Key,
	)

	eventJson, _ := json.Marshal(event)
	assert.Equal(t, eventJson, enrichedProducer.Value)
}

func TestProduceChargedInAdvanceEvent(t *testing.T) {
	setupProducerServiceEnv()

	event := models.EnrichedEvent{
		OrganizationID:         "1a901a90-1a90-1a90-1a90-1a901a901a90",
		ExternalSubscriptionID: "sub_id",
		Code:                   "api_calls",
		TransactionID:          "transaction_id",
	}

	producerService.ProduceChargedInAdvanceEvent(context.Background(), &event)

	assert.Equal(t, 1, inAdvanceProducer.ExecutionCount)
	assert.Equal(
		t,
		[]byte("1a901a90-1a90-1a90-1a90-1a901a901a90-transaction_id"),
		inAdvanceProducer.Key,
	)

	eventJson, _ := json.Marshal(event)
	assert.Equal(t, eventJson, inAdvanceProducer.Value)
}

func TestProduceToDeadLetterQueue(t *testing.T) {
	setupProducerServiceEnv()

	event := models.Event{
		OrganizationID:         "1a901a90-1a90-1a90-1a90-1a901a901a90",
		ExternalSubscriptionID: "sub_id",
		Code:                   "api_calls",
		TransactionID:          "transaction_id",
	}

	result := utils.FailedResult[string](fmt.Errorf("Error Message"))
	producerService.ProduceToDeadLetterQueue(context.Background(), event, result)

	var producedEvent models.FailedEvent
	err := json.Unmarshal(deadLetterProducer.Value, &producedEvent)

	assert.NoError(t, err)
	assert.Equal(t, 1, deadLetterProducer.ExecutionCount)

	assert.Equal(t, event, producedEvent.Event)
	assert.Equal(t, "Error Message", producedEvent.InitialErrorMessage)
	assert.Equal(t, "", producedEvent.ErrorCode)
	assert.Equal(t, "", producedEvent.ErrorMessage)
	assert.WithinDuration(t, time.Now(), producedEvent.FailedAt, 5*time.Second)
}
