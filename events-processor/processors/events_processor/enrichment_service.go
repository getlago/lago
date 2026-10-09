package events_processor

import (
	"time"

	"github.com/getlago/lago/events-processor/cache"
	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/processors/pipeline"
	"github.com/getlago/lago/events-processor/utils"
)

type EventEnrichmentService struct {
	apiStore *models.ApiStore
	memCache *cache.Cache
}

func NewEventEnrichmentService(apiStore *models.ApiStore, memCache *cache.Cache) *EventEnrichmentService {
	return &EventEnrichmentService{
		apiStore: apiStore,
		memCache: memCache,
	}
}

func (s *EventEnrichmentService) EnrichEvent(event *models.Event) utils.Result[*models.EnrichedEvent] {
	enrichedEventResult := pipeline.NewBillableMetricEnricher(s.apiStore, s.memCache).Enrich(event)
	if enrichedEventResult.Failure() {
		return enrichedEventResult
	}
	enrichedEvent := enrichedEventResult.Value()
	bm := enrichedEvent.BillableMetric

	subResult := s.fetchSubscription(event, enrichedEvent.Time)

	// For recurring billable metrics, if no subscription is active at the event
	// timestamp, fall back on the currently active subscription rather than failing.
	if subResult.Failure() && !subResult.IsCapturable() && bm != nil && bm.Recurring {
		subResult = s.fetchSubscription(event, time.Now())
	}

	if subResult.Failure() {
		if subResult.IsCapturable() {
			return failedResult(subResult, "fetch_subscription", "Error fetching subscription")
		}

		subResult = utils.SuccessResult[*models.Subscription](nil)
	}

	sub := subResult.Value()
	if sub != nil {
		enrichSubResult := s.enrichWithSubscription(enrichedEvent, sub)
		if enrichSubResult.Failure() {
			return enrichSubResult
		}
	}

	return utils.SuccessResult(enrichedEvent)
}

// HasPayInAdvanceCharge reports whether the event's plan charges the billable metric in advance.
func (s *EventEnrichmentService) HasPayInAdvanceCharge(enrichedEvent *models.EnrichedEvent) utils.Result[bool] {
	if enrichedEvent.BillableMetric == nil || enrichedEvent.PlanID == "" {
		return utils.SuccessResult(false)
	}

	if s.memCache != nil {
		return s.memCache.HasPayInAdvanceCharge(enrichedEvent.OrganizationID, enrichedEvent.PlanID, enrichedEvent.BillableMetric.ID)
	}

	return s.apiStore.HasPayInAdvanceCharge(enrichedEvent.OrganizationID, enrichedEvent.PlanID, enrichedEvent.BillableMetric.ID)
}

func (s *EventEnrichmentService) fetchSubscription(event *models.Event, timestamp time.Time) utils.Result[*models.Subscription] {
	if s.memCache != nil {
		return s.memCache.SearchSubscriptions(event.OrganizationID, event.ExternalSubscriptionID, timestamp)
	}
	return s.apiStore.FetchSubscription(event.OrganizationID, event.ExternalSubscriptionID, timestamp)
}

func (s *EventEnrichmentService) enrichWithSubscription(enrichedEvent *models.EnrichedEvent, sub *models.Subscription) utils.Result[*models.EnrichedEvent] {
	enrichedEvent.Subscription = sub
	enrichedEvent.SubscriptionID = sub.ID
	enrichedEvent.PlanID = sub.PlanID

	return utils.SuccessResult(enrichedEvent)
}
