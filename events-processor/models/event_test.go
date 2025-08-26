package models

import (
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestToEnrichedEvent(t *testing.T) {
	t.Run("With valid time format", func(t *testing.T) {
		expectedTime, _ := time.Parse(time.RFC3339, "2025-03-03T13:03:29Z")

		properties := map[string]any{
			"value": "12.12",
		}

		event := Event{
			OrganizationID:          "1a901a90-1a90-1a90-1a90-1a901a901a90",
			ExternalSubscriptionID:  "sub_id",
			Code:                    "api_calls",
			Properties:              properties,
			PreciseTotalAmountCents: "100.00",
			Source:                  HTTP_RUBY,
			Timestamp:               1741007009,
		}

		result := event.ToEnrichedEvent()
		assert.True(t, result.Success())

		ere := result.Value()
		assert.Equal(t, event.OrganizationID, ere.OrganizationID)
		assert.Equal(t, event.ExternalSubscriptionID, ere.ExternalSubscriptionID)
		assert.Equal(t, event.Code, ere.Code)
		assert.Equal(t, event.Properties, ere.Properties)
		assert.Equal(t, event.PreciseTotalAmountCents, ere.PreciseTotalAmountCents)
		assert.Equal(t, event.Source, ere.Source)
		assert.Equal(t, 1741007009.0, ere.Timestamp)
		assert.Equal(t, expectedTime, ere.Time)
		assert.Equal(t, map[string]string{}, ere.GroupedBy)
	})

	t.Run("With unsupported time format", func(t *testing.T) {
		event := Event{
			OrganizationID:          "1a901a90-1a90-1a90-1a90-1a901a901a90",
			ExternalSubscriptionID:  "sub_id",
			Code:                    "api_calls",
			PreciseTotalAmountCents: "100.00",
			Source:                  HTTP_RUBY,
			Timestamp:               "2025-03-03T13:03:29Z",
		}

		result := event.ToEnrichedEvent()
		assert.False(t, result.Success())
		assert.Equal(t, "strconv.ParseFloat: parsing \"2025-03-03T13:03:29Z\": invalid syntax", result.ErrorMsg())
		assert.False(t, result.Retryable)
	})
}

func TestNotAPIPostProcessed(t *testing.T) {
	t.Run("When event source is not HTTP_RUBY", func(t *testing.T) {
		event := Event{
			Source: "REDPANDA_CONNECT",
		}

		assert.True(t, event.NotAPIPostProcessed())
	})

	t.Run("When event source is HTTP_RUBY without source metadata", func(t *testing.T) {
		event := Event{
			Source: HTTP_RUBY,
		}

		assert.True(t, event.NotAPIPostProcessed())
	})

	t.Run("When event source is HTTP_RUBY with source metadata", func(t *testing.T) {
		event := Event{
			Source: HTTP_RUBY,
			SourceMetadata: &SourceMetadata{
				ApiPostProcess: true,
			},
		}
		assert.False(t, event.NotAPIPostProcessed())

		event.SourceMetadata.ApiPostProcess = false
		assert.True(t, event.NotAPIPostProcessed())
	})
}
