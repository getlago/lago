package models

import (
	"encoding/json"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestProductEventFromAPIPayload(t *testing.T) {
	// The payload lago-api produces to the product raw events topic.
	payload := `{
		"organization_id": "1a901a90-1a90-1a90-1a90-1a901a901a90",
		"external_customer_id": "cust_1",
		"external_contract_id": "contract_1",
		"transaction_id": "tx_1",
		"timestamp": "1741007009.123",
		"code": "api_calls",
		"precise_total_amount_cents": "0.0",
		"properties": {"value": "12.12"},
		"ingested_at": "2025-03-03T13:03:30.456",
		"source": "http_ruby",
		"source_metadata": {"api_post_processed": false}
	}`

	var event ProductEvent
	require.NoError(t, json.Unmarshal([]byte(payload), &event))

	assert.Equal(t, "contract_1", event.ExternalContractID)
	assert.Equal(t, "tx_1", event.TransactionID)
	assert.Equal(t, int64(1741007010456), event.IngestedTime().UnixMilli())
}

func TestToProductEnrichedEvent(t *testing.T) {
	t.Run("With valid time format", func(t *testing.T) {
		event := ProductEvent{
			OrganizationID:          "1a901a90-1a90-1a90-1a90-1a901a901a90",
			ExternalContractID:      "contract_1",
			TransactionID:           "tx_1",
			Code:                    "api_calls",
			Properties:              map[string]any{"value": "12.12"},
			PreciseTotalAmountCents: "100.00",
			Source:                  HTTP_RUBY,
			Timestamp:               1741007009,
		}

		result := event.ToProductEnrichedEvent()
		require.True(t, result.Success())

		enriched := result.Value()
		assert.Same(t, &event, enriched.InitialEvent)
		assert.Equal(t, event.ExternalContractID, enriched.ExternalContractID)
		assert.Equal(t, event.Properties, enriched.Properties)
		assert.Equal(t, 1741007009.0, enriched.Timestamp)

		// The keys are the product_events_enriched queue columns: no subscription.
		var payload map[string]any
		data, err := json.Marshal(enriched)
		require.NoError(t, err)
		require.NoError(t, json.Unmarshal(data, &payload))
		assert.Equal(t, "contract_1", payload["external_contract_id"])
		assert.NotContains(t, payload, "external_subscription_id")
	})

	t.Run("With unsupported time format", func(t *testing.T) {
		event := ProductEvent{ExternalContractID: "contract_1", Timestamp: "2025-03-03 13:03:29"}

		result := event.ToProductEnrichedEvent()
		assert.False(t, result.Success())
		assert.False(t, result.Retryable)
	})
}

func TestDeadLetterEventOfProductEvent(t *testing.T) {
	data, err := json.Marshal(DeadLetterEvent[ProductEvent]{Event: ProductEvent{ExternalContractID: "contract_1"}})
	require.NoError(t, err)

	var payload struct {
		Event map[string]any `json:"event"`
	}
	require.NoError(t, json.Unmarshal(data, &payload))
	assert.Equal(t, "contract_1", payload.Event["external_contract_id"])
	assert.NotContains(t, payload.Event, "external_subscription_id")
}

func TestProductEventNotAPIPostProcessed(t *testing.T) {
	t.Run("When event source is not HTTP_RUBY", func(t *testing.T) {
		event := ProductEvent{Source: "REDPANDA_CONNECT"}

		assert.True(t, event.NotAPIPostProcessed())
	})

	t.Run("When event source is HTTP_RUBY without source metadata", func(t *testing.T) {
		event := ProductEvent{Source: HTTP_RUBY}

		assert.True(t, event.NotAPIPostProcessed())
	})

	t.Run("When event source is HTTP_RUBY with source metadata", func(t *testing.T) {
		event := ProductEvent{Source: HTTP_RUBY, SourceMetadata: &SourceMetadata{ApiPostProcess: true}}
		assert.False(t, event.NotAPIPostProcessed())

		event.SourceMetadata.ApiPostProcess = false
		assert.True(t, event.NotAPIPostProcessed())
	})
}
