package product_processor

import (
	"context"
	"encoding/json"
	"errors"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/processors/pipeline"
	"github.com/getlago/lago/events-processor/tests"
	"github.com/getlago/lago/events-processor/utils"
)

func TestProduceEnrichedEvent(t *testing.T) {
	enrichedProducer := &tests.MockMessageProducer{}
	producerService := NewProducerService(enrichedProducer, nil, &tests.MockMessageProducer{})

	event := models.ProductEnrichedEvent{
		OrganizationID:     orgID,
		ExternalContractID: "contract_ext_id",
		Code:               "api_calls",
		TransactionID:      "transaction_id",
	}

	producerService.ProduceEnrichedEvent(context.Background(), &event)

	assert.Equal(t, 1, enrichedProducer.ExecutionCount)
	assert.Equal(t, []byte(orgID+"-transaction_id"), enrichedProducer.Key)

	// The keys are the product_events_enriched queue columns.
	var payload map[string]any
	assert.NoError(t, json.Unmarshal(enrichedProducer.Value, &payload))
	assert.Equal(t, "contract_ext_id", payload["external_contract_id"])
	assert.NotContains(t, payload, "external_subscription_id")
}

func TestProduceChargedInAdvanceEvent(t *testing.T) {
	inAdvanceProducer := &tests.MockMessageProducer{}
	producerService := NewProducerService(&tests.MockMessageProducer{}, inAdvanceProducer, &tests.MockMessageProducer{})

	event := models.ProductEnrichedEvent{
		OrganizationID:     orgID,
		ExternalContractID: "contract_ext_id",
		Code:               "api_calls",
		TransactionID:      "transaction_id",
	}

	producerService.ProduceChargedInAdvanceEvent(context.Background(), &event)

	assert.Equal(t, 1, inAdvanceProducer.ExecutionCount)
	assert.Equal(t, []byte(orgID+"-transaction_id"), inAdvanceProducer.Key)

	// The same payload as product_events_enriched, keyed by contract.
	var payload map[string]any
	assert.NoError(t, json.Unmarshal(inAdvanceProducer.Value, &payload))
	assert.Equal(t, "contract_ext_id", payload["external_contract_id"])
	assert.NotContains(t, payload, "external_subscription_id")
}

func TestChargesInAdvance(t *testing.T) {
	t.Run("with the in advance topic", func(t *testing.T) {
		producerService := NewProducerService(&tests.MockMessageProducer{}, &tests.MockMessageProducer{}, &tests.MockMessageProducer{})

		assert.True(t, producerService.ChargesInAdvance())
	})

	t.Run("without the in advance topic", func(t *testing.T) {
		producerService := NewProducerService(&tests.MockMessageProducer{}, nil, &tests.MockMessageProducer{})

		assert.False(t, producerService.ChargesInAdvance())
	})
}

func TestProduceToDeadLetterQueue(t *testing.T) {
	deadLetterProducer := &tests.MockMessageProducer{}
	producerService := NewProducerService(&tests.MockMessageProducer{}, nil, deadLetterProducer)

	failure := utils.FailedResult[*models.ProductEnrichedEvent](errors.New("billable metric not found"))
	errorResult := pipeline.FailedResult[*models.ProductEnrichedEvent](failure, "fetch_billable_metric", "Error fetching billable metric")

	producerService.ProduceToDeadLetterQueue(context.Background(), buildEvent(), errorResult)

	assert.Equal(t, 1, deadLetterProducer.ExecutionCount)

	// The keys are the product_events_dead_letter_queue columns, and the event keeps
	// the contract id the dead letter table is ordered by.
	var payload map[string]any
	require.NoError(t, json.Unmarshal(deadLetterProducer.Value, &payload))
	assert.ElementsMatch(t, []string{"event", "initial_error_message", "error_code", "error_message", "failed_at"}, keys(payload))
	assert.Equal(t, "fetch_billable_metric", payload["error_code"])
	assert.Equal(t, "contract_ext_id", payload["event"].(map[string]any)["external_contract_id"])
}

func keys(payload map[string]any) []string {
	result := make([]string, 0, len(payload))
	for key := range payload {
		result = append(result, key)
	}
	return result
}
