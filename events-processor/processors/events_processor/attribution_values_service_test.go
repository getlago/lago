package events_processor

import (
	"context"
	"encoding/json"
	"strconv"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/getlago/lago/events-processor/config/kafka"
	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/tests"
)

func setupAttributionValuesService(producer kafka.MessageProducer) (*AttributionValuesService, *time.Time) {
	now := time.Date(2026, 10, 14, 10, 0, 0, 0, time.UTC)

	service := NewAttributionValuesService(producer)
	service.now = func() time.Time { return now }

	return service, &now
}

func labeledEvent(subscriptionID string, labels map[string]string) *models.EnrichedEvent {
	return &models.EnrichedEvent{
		OrganizationID:    "1a901a90-1a90-1a90-1a90-1a901a901a90",
		SubscriptionID:    subscriptionID,
		AttributionLabels: labels,
		Timestamp:         1741007009.123,
	}
}

func TestReportAttributionValues(t *testing.T) {
	ctx := context.Background()
	labels := map[string]string{"department": "rnd", "user": "alice"}

	t.Run("reports the values of the event", func(t *testing.T) {
		producer := &tests.MockMessageProducer{}
		service, _ := setupAttributionValuesService(producer)

		service.ReportAttributionValues(ctx, labeledEvent("sub123", labels))

		require.Equal(t, 1, producer.ExecutionCount)
		assert.Equal(t, []byte("1a901a90-1a90-1a90-1a90-1a901a901a90-sub123"), producer.Key)

		var message models.AttributionValuesMessage
		require.NoError(t, json.Unmarshal(producer.Value, &message))
		assert.Equal(t, models.AttributionValuesMessage{
			OrganizationID:    "1a901a90-1a90-1a90-1a90-1a901a901a90",
			SubscriptionID:    "sub123",
			AttributionLabels: labels,
			Timestamp:         1741007009.123,
		}, message)
	})

	t.Run("reports a combination once within the TTL", func(t *testing.T) {
		producer := &tests.MockMessageProducer{}
		service, now := setupAttributionValuesService(producer)

		service.ReportAttributionValues(ctx, labeledEvent("sub123", labels))
		*now = now.Add(59 * time.Minute)
		service.ReportAttributionValues(ctx, labeledEvent("sub123", map[string]string{"user": "alice", "department": "rnd"}))

		assert.Equal(t, 1, producer.ExecutionCount)
	})

	t.Run("reports a combination again once the TTL is over", func(t *testing.T) {
		producer := &tests.MockMessageProducer{}
		service, now := setupAttributionValuesService(producer)

		service.ReportAttributionValues(ctx, labeledEvent("sub123", labels))
		*now = now.Add(time.Hour)
		service.ReportAttributionValues(ctx, labeledEvent("sub123", labels))

		assert.Equal(t, 2, producer.ExecutionCount)
	})

	t.Run("reports a combination again for an event a TTL newer than the reported one", func(t *testing.T) {
		producer := &tests.MockMessageProducer{}
		service, _ := setupAttributionValuesService(producer)

		lateEvent := labeledEvent("sub123", labels)
		liveEvent := labeledEvent("sub123", labels)
		liveEvent.Timestamp = lateEvent.Timestamp + time.Hour.Seconds()

		service.ReportAttributionValues(ctx, lateEvent)
		service.ReportAttributionValues(ctx, liveEvent)

		require.Equal(t, 2, producer.ExecutionCount)

		var message models.AttributionValuesMessage
		require.NoError(t, json.Unmarshal(producer.Value, &message))
		assert.Equal(t, liveEvent.Timestamp, message.Timestamp)
	})

	t.Run("does not report a combination again for an older event within the TTL", func(t *testing.T) {
		producer := &tests.MockMessageProducer{}
		service, _ := setupAttributionValuesService(producer)

		liveEvent := labeledEvent("sub123", labels)
		lateEvent := labeledEvent("sub123", labels)
		lateEvent.Timestamp = liveEvent.Timestamp - 30*24*time.Hour.Seconds()

		service.ReportAttributionValues(ctx, liveEvent)
		service.ReportAttributionValues(ctx, lateEvent)

		assert.Equal(t, 1, producer.ExecutionCount)
	})

	t.Run("reports other labels and other subscriptions", func(t *testing.T) {
		producer := &tests.MockMessageProducer{}
		service, _ := setupAttributionValuesService(producer)

		service.ReportAttributionValues(ctx, labeledEvent("sub123", labels))
		service.ReportAttributionValues(ctx, labeledEvent("sub123", map[string]string{"department": "rnd", "user": "bob"}))
		service.ReportAttributionValues(ctx, labeledEvent("sub456", labels))

		assert.Equal(t, 3, producer.ExecutionCount)
	})

	t.Run("reports a combination again when it failed to be pushed", func(t *testing.T) {
		producer := &tests.MockMessageProducer{Fail: true}
		service, _ := setupAttributionValuesService(producer)

		service.ReportAttributionValues(ctx, labeledEvent("sub123", labels))
		service.ReportAttributionValues(ctx, labeledEvent("sub123", labels))

		assert.Equal(t, 2, producer.ExecutionCount)
	})

	t.Run("drops the expired combinations when full", func(t *testing.T) {
		producer := &tests.MockMessageProducer{}
		service, now := setupAttributionValuesService(producer)
		for i := range attributionValuesMaxReported {
			service.reported[strconv.Itoa(i)] = reportedCombination{reportedAt: now.Add(-time.Hour)}
		}
		service.reported["fresh"] = reportedCombination{reportedAt: *now}

		service.ReportAttributionValues(ctx, labeledEvent("sub123", labels))

		assert.Equal(t, 1, producer.ExecutionCount)
		assert.Len(t, service.reported, 2)
		assert.Contains(t, service.reported, "fresh")
	})

	t.Run("forgets every combination when full of unexpired ones", func(t *testing.T) {
		producer := &tests.MockMessageProducer{}
		service, now := setupAttributionValuesService(producer)
		for i := range attributionValuesMaxReported {
			service.reported[strconv.Itoa(i)] = reportedCombination{reportedAt: *now}
		}

		service.ReportAttributionValues(ctx, labeledEvent("sub123", labels))

		assert.Equal(t, 1, producer.ExecutionCount)
		assert.Len(t, service.reported, 1)
	})

	t.Run("does not report events without labels or subscription", func(t *testing.T) {
		producer := &tests.MockMessageProducer{}
		service, _ := setupAttributionValuesService(producer)

		service.ReportAttributionValues(ctx, labeledEvent("sub123", nil))
		service.ReportAttributionValues(ctx, labeledEvent("", labels))

		assert.Equal(t, 0, producer.ExecutionCount)
	})

	t.Run("does not report without a producer", func(t *testing.T) {
		service, _ := setupAttributionValuesService(nil)

		assert.NotPanics(t, func() { service.ReportAttributionValues(ctx, labeledEvent("sub123", labels)) })
		assert.Empty(t, service.reported)
	})
}
