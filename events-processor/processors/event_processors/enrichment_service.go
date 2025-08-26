package event_processors

import (
	"encoding/json"
	"fmt"

	"github.com/getlago/lago-expression/expression-go"
	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/utils"
)

type EventEnrichmentService struct {
	apiStore *models.ApiStore
}

func NewEventEnrichmentService(apiStore *models.ApiStore) *EventEnrichmentService {
	return &EventEnrichmentService{
		apiStore: apiStore,
	}
}

func (s *EventEnrichmentService) EnrichEvent(event *models.Event) utils.Result[[]*models.EnrichedEvent] {
	enrichedEventResult := event.ToEnrichedEvent()
	if enrichedEventResult.Failure() {
		return failedMultiEventsResult(enrichedEventResult, "build_enriched_event", "Error while converting event to enriched event")
	}
	enrichedEvent := enrichedEventResult.Value()

	bmResult := s.apiStore.FetchBillableMetric(event.OrganizationID, event.Code)
	if bmResult.Failure() {
		return failedMultiEventsResult(bmResult, "fetch_billable_metric", "Error fetching billable metric")
	}

	bm := bmResult.Value()
	if bm != nil {
		enrichBmResult := s.enrichWithBillableMetric(enrichedEvent, bm)
		if enrichBmResult.Failure() {
			return toMultiEventsResult(enrichBmResult)
		}
	}

	subResult := s.apiStore.FetchSubscription(event.OrganizationID, event.ExternalSubscriptionID, enrichedEvent.Time)
	if subResult.Failure() && subResult.IsCapturable() {
		// We want to keep processing the event even if the subscription is not found
		return failedMultiEventsResult(subResult, "fetch_subscription", "Error fetching subscription")
	}

	sub := subResult.Value()
	if sub != nil {
		enrichSubResult := s.enrichWithSubscription(enrichedEvent, sub)
		if enrichSubResult.Failure() {
			return toMultiEventsResult(enrichSubResult)
		}
	}

	enrichedEvents := s.enrichWithChargeInfo(enrichedEvent)
	return enrichedEvents
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
			FailedBoolResult(fmt.Errorf("Failed to evaluate expr: %s with json: %s", bm.Expression, eventJsonString)).
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

func (s *EventEnrichmentService) enrichWithChargeInfo(enrichedEvent *models.EnrichedEvent) utils.Result[[]*models.EnrichedEvent] {
	// TODO(pre-aggregation): Remove the NotAPIPostProcessed condition to enable pre-aggregation
	if !enrichedEvent.InitialEvent.NotAPIPostProcessed() || enrichedEvent.Subscription == nil {
		return utils.SuccessResult([]*models.EnrichedEvent{enrichedEvent})
	}

	filtersResult := s.apiStore.FetchFlatFilters(enrichedEvent.PlanID, enrichedEvent.Code)
	if filtersResult.Failure() {
		return utils.FailedResult[[]*models.EnrichedEvent](filtersResult.Error())
	}

	filters := filtersResult.Value()
	if len(filters) == 0 {
		// No filters found, return the original event without charge information
		return utils.SuccessResult([]*models.EnrichedEvent{enrichedEvent})
	}

	// Index filters by charge ID (an event can match multiple charges and filters)
	charges := make(map[string][]models.FlatFilter)
	for _, filter := range filters {
		if charges[filter.ChargeID] == nil {
			charges[filter.ChargeID] = []models.FlatFilter{}
		}
		charges[filter.ChargeID] = append(charges[filter.ChargeID], filter)
	}

	var enrichedEvents []*models.EnrichedEvent
	// For each charge, find matching filter and create an enriched event
	for _, chargeFilters := range charges {
		matchingFilter := models.MatchingFilter(chargeFilters, enrichedEvent)

		// Create a copy of the enriched event for this filter
		enrichedEventCopy := *enrichedEvent
		enrichedEventCopy.GroupedBy = make(map[string]string)

		// Populate charge information
		enrichedEventCopy.FlatFilter = matchingFilter
		enrichedEventCopy.ChargeID = &matchingFilter.ChargeID
		enrichedEventCopy.ChargeUpdatedAt = &matchingFilter.ChargeUpdatedAt
		enrichedEventCopy.ChargeFilterID = matchingFilter.ChargeFilterID
		enrichedEventCopy.ChargeFilterUpdatedAt = matchingFilter.ChargeFilterUpdatedAt

		enrichWithPricingGroupKeys(&enrichedEventCopy)

		enrichedEvents = append(enrichedEvents, &enrichedEventCopy)
	}

	return utils.SuccessResult(enrichedEvents)
}

func enrichWithPricingGroupKeys(event *models.EnrichedEvent) {
	if event.FlatFilter == nil || event.FlatFilter.PricingGroupKeys == nil {
		return
	}

	for _, key := range event.FlatFilter.PricingGroupKeys {
		event.GroupedBy[key] = fmt.Sprintf("%v", event.Properties[key])
	}
}
