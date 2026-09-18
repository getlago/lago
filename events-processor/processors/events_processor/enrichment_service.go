package events_processor

import (
	"encoding/json"
	"fmt"
	"time"

	"github.com/getlago/lago-expression/expression-go"

	"github.com/getlago/lago/events-processor/cache"
	"github.com/getlago/lago/events-processor/models"
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
	enrichedEventResult := event.ToEnrichedEvent()
	if enrichedEventResult.Failure() {
		return failedResult(enrichedEventResult, "build_enriched_event", "Error while converting event to enriched event")
	}
	enrichedEvent := enrichedEventResult.Value()

	var bmResult utils.Result[*models.BillableMetric]

	if s.memCache != nil {
		bmResult = s.memCache.GetBillableMetric(event.OrganizationID, event.Code)
	} else {
		bmResult = s.apiStore.FetchBillableMetric(event.OrganizationID, event.Code)
	}
	if bmResult.Failure() {
		return failedResult(bmResult, "fetch_billable_metric", "Error fetching billable metric")
	}

	bm := bmResult.Value()
	if bm != nil {
		enrichBmResult := s.enrichWithBillableMetric(enrichedEvent, bm)
		if enrichBmResult.Failure() {
			return enrichBmResult
		}
	}

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

func (s *EventEnrichmentService) enrichWithBillableMetric(enrichedEvent *models.EnrichedEvent, bm *models.BillableMetric) utils.Result[*models.EnrichedEvent] {
	enrichedEvent.BillableMetric = bm
	enrichedEvent.AggregationType = bm.AggregationType.String()

	if enrichedEvent.Source != models.HTTP_RUBY {
		expressionResult := s.evaluateExpression(enrichedEvent, bm)
		if expressionResult.Failure() {
			return failedResult(expressionResult, "evaluate_expression", "Error evaluating custom expression")
		}
	}

	if bm.AggregationType == models.AggregationTypeCount {
		enrichedEvent.Value = utils.StringPtr("1")
	} else {
		var value = fmt.Sprintf("%v", enrichedEvent.Properties[bm.FieldName])
		enrichedEvent.Value = &value
	}

	return utils.SuccessResult(enrichedEvent)
}

func (s *EventEnrichmentService) evaluateExpression(ev *models.EnrichedEvent, bm *models.BillableMetric) utils.Result[bool] {
	if bm.Expression == "" {
		return utils.SuccessResult(false)
	}

	eventJson, err := json.Marshal(ev)
	if err != nil {
		return utils.FailedBoolResult(err).NonRetryable()
	}
	eventJsonString := string(eventJson[:])

	result := expression.Evaluate(bm.Expression, eventJsonString)
	if result != nil {
		ev.Properties[bm.FieldName] = *result
	} else {
		return utils.
			FailedBoolResult(fmt.Errorf("failed to evaluate expr: %s with json: %s", bm.Expression, eventJsonString)).
			NonRetryable()
	}

	return utils.SuccessResult(true)
}

func (s *EventEnrichmentService) enrichWithSubscription(enrichedEvent *models.EnrichedEvent, sub *models.Subscription) utils.Result[*models.EnrichedEvent] {
	enrichedEvent.Subscription = sub
	enrichedEvent.SubscriptionID = sub.ID
	enrichedEvent.PlanID = sub.PlanID

	return utils.SuccessResult(enrichedEvent)
}
