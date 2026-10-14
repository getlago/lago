package events_processor

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"sync"
	"time"

	"github.com/getlago/lago/events-processor/config/kafka"
	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/utils"
)

const (
	// A combination is reported again once this delay is over, which keeps its last_seen_at fresh.
	attributionValuesReportTTL = time.Hour

	// Bounds the memory of the reported combinations. When full, they are all forgotten: they are
	// reported again, which the API handles as idempotent upserts.
	attributionValuesMaxReported = 100_000
)

// AttributionValuesService reports the account tree values carried by enriched events, so that the
// API stores them in usage_attribution_values. Every subscription + labels combination is reported
// at most once per TTL by each processor instance.
type AttributionValuesService struct {
	producer kafka.MessageProducer
	now      func() time.Time

	mu       sync.Mutex
	reported map[string]time.Time
}

// NewAttributionValuesService returns a service reporting to the producer. Without a producer,
// nothing is reported.
func NewAttributionValuesService(producer kafka.MessageProducer) *AttributionValuesService {
	return &AttributionValuesService{
		producer: producer,
		now:      time.Now,
		reported: make(map[string]time.Time),
	}
}

func (s *AttributionValuesService) ReportAttributionValues(ctx context.Context, event *models.EnrichedEvent) {
	if s.producer == nil || len(event.AttributionLabels) == 0 || event.SubscriptionID == "" {
		return
	}

	message := models.AttributionValuesMessage{
		OrganizationID:    event.OrganizationID,
		SubscriptionID:    event.SubscriptionID,
		AttributionLabels: event.AttributionLabels,
		Timestamp:         event.Timestamp,
	}

	// Map keys are marshaled in sorted order, so the same labels always give the same key.
	labelsJson, err := json.Marshal(message.AttributionLabels)
	if err != nil {
		slog.Error("error while marshaling attribution labels", slog.String("error", err.Error()))
		utils.CaptureError(err)
		return
	}

	key := fmt.Sprintf("%s|%s|%s", message.OrganizationID, message.SubscriptionID, labelsJson)
	if !s.markReported(key) {
		return
	}

	messageJson, err := json.Marshal(message)
	if err != nil {
		s.forget(key)
		slog.Error("error while marshaling attribution values", slog.String("error", err.Error()))
		utils.CaptureError(err)
		return
	}

	pushed := s.producer.Produce(ctx, &kafka.ProducerMessage{
		Key:   []byte(fmt.Sprintf("%s-%s", message.OrganizationID, message.SubscriptionID)),
		Value: messageJson,
	})

	// The values are reported again by the next event with the same combination.
	if !pushed {
		s.forget(key)
		slog.Error("error while pushing attribution values", slog.String("topic", s.producer.GetTopic()))
	}
}

// markReported records the combination as reported, before it is produced, so that events of the
// same batch processed concurrently report it once. Returns false when it was reported within the TTL.
func (s *AttributionValuesService) markReported(key string) bool {
	s.mu.Lock()
	defer s.mu.Unlock()

	now := s.now()
	if reportedAt, ok := s.reported[key]; ok && now.Sub(reportedAt) < attributionValuesReportTTL {
		return false
	}

	if len(s.reported) >= attributionValuesMaxReported {
		s.reported = make(map[string]time.Time)
	}

	s.reported[key] = now
	return true
}

func (s *AttributionValuesService) forget(key string) {
	s.mu.Lock()
	defer s.mu.Unlock()

	delete(s.reported, key)
}
