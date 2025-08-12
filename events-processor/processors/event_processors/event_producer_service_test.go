package event_processors

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"os"
	"testing"
	"time"

	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/tests"
	"github.com/getlago/lago/events-processor/utils"
	"github.com/stretchr/testify/assert"
)

var (
	producerService          *EventProducerService
	enrichedProducer         *tests.MockMessageProducer
	enrichedExpandedProducer *tests.MockMessageProducer
	inAdvanceProducer        *tests.MockMessageProducer
	deadLetterProducer       *tests.MockMessageProducer
	logger                   *slog.Logger
)

func setupProducerServiceEnv() {
	enrichedProducer = &tests.MockMessageProducer{}
	enrichedExpandedProducer = &tests.MockMessageProducer{}
	inAdvanceProducer = &tests.MockMessageProducer{}
	deadLetterProducer = &tests.MockMessageProducer{}

	logger = slog.New(slog.NewJSONHandler(os.Stdout, nil))
	slog.SetDefault(logger)

	producerService = NewEventProducerService(
		enrichedProducer,
		enrichedExpandedProducer,
		inAdvanceProducer,
		deadLetterProducer,
		logger,
	)
}

func TestProduceEnrichedEvent(t *testing.T) {
	setupProducerServiceEnv()

	event := models.EnrichedEvent{
		OrganizationID:         "1a901a90-1a90-1a90-1a90-1a901a901a90",
		ExternalSubscriptionID: "sub_id",
		Code:                   "api_calls",
	}

	producerService.ProduceEnrichedEvent(context.Background(), &event)

	assert.Equal(t, 1, enrichedProducer.ExecutionCount)
	assert.Equal(
		t,
		[]byte("1a901a90-1a90-1a90-1a90-1a901a901a90-sub_id-api_calls"),
		enrichedProducer.Key,
	)

	eventJson, _ := json.Marshal(event)
	assert.Equal(t, eventJson, enrichedProducer.Value)
}

func TestProduceEnrichedExtendedEvent(t *testing.T) {
	t.Run("Without charge details", func(t *testing.T) {
		setupProducerServiceEnv()

		event := models.EnrichedEvent{
			OrganizationID:         "1a901a90-1a90-1a90-1a90-1a901a901a90",
			ExternalSubscriptionID: "sub_id",
			Code:                   "api_calls",
		}

		producerService.ProduceEnrichedExpendedEvent(context.Background(), &event)

		assert.Equal(t, 1, enrichedExpandedProducer.ExecutionCount)
		assert.Equal(
			t,
			[]byte("1a901a90-1a90-1a90-1a90-1a901a901a90-sub_id-api_calls---"),
			enrichedExpandedProducer.Key,
		)

		eventJson, _ := json.Marshal(event)
		assert.Equal(t, eventJson, enrichedExpandedProducer.Value)
	})

	t.Run("With a charge id", func(t *testing.T) {
		setupProducerServiceEnv()

		event := models.EnrichedEvent{
			OrganizationID:         "1a901a90-1a90-1a90-1a90-1a901a901a90",
			ExternalSubscriptionID: "sub_id",
			Code:                   "api_calls",
			ChargeID:               utils.StringPtr("charge_id"),
		}

		producerService.ProduceEnrichedExpendedEvent(context.Background(), &event)

		assert.Equal(t, 1, enrichedExpandedProducer.ExecutionCount)
		assert.Equal(
			t,
			[]byte("1a901a90-1a90-1a90-1a90-1a901a901a90-sub_id-api_calls-charge_id--"),
			enrichedExpandedProducer.Key,
		)

		eventJson, _ := json.Marshal(event)
		assert.Equal(t, eventJson, enrichedExpandedProducer.Value)
	})

	t.Run("With a charge filter id", func(t *testing.T) {
		setupProducerServiceEnv()

		event := models.EnrichedEvent{
			OrganizationID:         "1a901a90-1a90-1a90-1a90-1a901a901a90",
			ExternalSubscriptionID: "sub_id",
			Code:                   "api_calls",
			ChargeFilterID:         utils.StringPtr("charge_filter_id"),
		}

		producerService.ProduceEnrichedExpendedEvent(context.Background(), &event)

		assert.Equal(t, 1, enrichedExpandedProducer.ExecutionCount)
		assert.Equal(
			t,
			[]byte("1a901a90-1a90-1a90-1a90-1a901a901a90-sub_id-api_calls--charge_filter_id-"),
			enrichedExpandedProducer.Key,
		)

		eventJson, _ := json.Marshal(event)
		assert.Equal(t, eventJson, enrichedExpandedProducer.Value)
	})

	t.Run("With groups", func(t *testing.T) {
		setupProducerServiceEnv()

		event := models.EnrichedEvent{
			OrganizationID:         "1a901a90-1a90-1a90-1a90-1a901a901a90",
			ExternalSubscriptionID: "sub_id",
			Code:                   "api_calls",
			GroupedBy:              map[string]string{"country": "US", "type": "debit"},
		}

		producerService.ProduceEnrichedExpendedEvent(context.Background(), &event)

		assert.Equal(t, 1, enrichedExpandedProducer.ExecutionCount)
		assert.Equal(
			t,
			[]byte("1a901a90-1a90-1a90-1a90-1a901a901a90-sub_id-api_calls---country/US|type/debit"),
			enrichedExpandedProducer.Key,
		)

		eventJson, _ := json.Marshal(event)
		assert.Equal(t, eventJson, enrichedExpandedProducer.Value)
	})

	t.Run("With groups unsorted", func(t *testing.T) {
		setupProducerServiceEnv()

		event := models.EnrichedEvent{
			OrganizationID:         "1a901a90-1a90-1a90-1a90-1a901a901a90",
			ExternalSubscriptionID: "sub_id",
			Code:                   "api_calls",
			GroupedBy:              map[string]string{"type": "debit", "country": "US"},
		}

		producerService.ProduceEnrichedExpendedEvent(context.Background(), &event)

		assert.Equal(t, 1, enrichedExpandedProducer.ExecutionCount)
		assert.Equal(
			t,
			[]byte("1a901a90-1a90-1a90-1a90-1a901a901a90-sub_id-api_calls---country/US|type/debit"),
			enrichedExpandedProducer.Key,
		)

		eventJson, _ := json.Marshal(event)
		assert.Equal(t, eventJson, enrichedExpandedProducer.Value)
	})
}

func TestProduceChargedInAdvanceEvent(t *testing.T) {
	setupProducerServiceEnv()

	event := models.EnrichedEvent{
		OrganizationID:         "1a901a90-1a90-1a90-1a90-1a901a901a90",
		ExternalSubscriptionID: "sub_id",
		Code:                   "api_calls",
	}

	producerService.ProduceChargedInAdvanceEvent(context.Background(), &event)

	assert.Equal(t, 1, inAdvanceProducer.ExecutionCount)
	assert.Equal(
		t,
		[]byte("1a901a90-1a90-1a90-1a90-1a901a901a90-sub_id-api_calls"),
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
