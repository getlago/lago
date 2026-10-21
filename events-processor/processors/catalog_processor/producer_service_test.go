package catalog_processor

import (
	"context"
	"encoding/json"
	"testing"

	"github.com/stretchr/testify/assert"

	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/tests"
)

func TestProduceEnrichedEvent(t *testing.T) {
	enrichedProducer := &tests.MockMessageProducer{}
	producerService := NewProducerService(enrichedProducer, &tests.MockMessageProducer{}, &tests.MockMessageProducer{})

	event := models.CatalogEnrichedEvent{
		OrganizationID:     orgID,
		ExternalContractID: "contract_ext_id",
		Code:               "api_calls",
		TransactionID:      "transaction_id",
	}

	producerService.ProduceEnrichedEvent(context.Background(), &event)

	assert.Equal(t, 1, enrichedProducer.ExecutionCount)
	assert.Equal(t, []byte(orgID+"-transaction_id"), enrichedProducer.Key)

	// The keys are the catalog_events_enriched queue columns.
	var payload map[string]any
	assert.NoError(t, json.Unmarshal(enrichedProducer.Value, &payload))
	assert.Equal(t, "contract_ext_id", payload["external_contract_id"])
	assert.NotContains(t, payload, "external_subscription_id")
}
