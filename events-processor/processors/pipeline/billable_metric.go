package pipeline

import (
	"encoding/json"
	"fmt"

	"github.com/getlago/lago-expression/expression-go"

	"github.com/getlago/lago/events-processor/cache"
	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/utils"
)

// BillableMetricEnricher builds the enriched event and computes its value from
// the billable metric of its code.
type BillableMetricEnricher struct {
	apiStore *models.ApiStore
	memCache *cache.Cache
}

func NewBillableMetricEnricher(apiStore *models.ApiStore, memCache *cache.Cache) BillableMetricEnricher {
	return BillableMetricEnricher{apiStore: apiStore, memCache: memCache}
}

func (e BillableMetricEnricher) Enrich(event *models.Event) utils.Result[*models.EnrichedEvent] {
	enrichedEventResult := event.ToEnrichedEvent()
	if enrichedEventResult.Failure() {
		return FailedResult[*models.EnrichedEvent](enrichedEventResult, "build_enriched_event", "Error while converting event to enriched event")
	}
	enrichedEvent := enrichedEventResult.Value()

	var bmResult utils.Result[*models.BillableMetric]

	if e.memCache != nil {
		bmResult = e.memCache.GetBillableMetric(event.OrganizationID, event.Code)
	} else {
		bmResult = e.apiStore.FetchBillableMetric(event.OrganizationID, event.Code)
	}
	if bmResult.Failure() {
		return FailedResult[*models.EnrichedEvent](bmResult, "fetch_billable_metric", "Error fetching billable metric")
	}

	bm := bmResult.Value()
	if bm != nil {
		enrichBmResult := enrichWithBillableMetric(enrichedEvent, bm)
		if enrichBmResult.Failure() {
			return enrichBmResult
		}
	}

	return utils.SuccessResult(enrichedEvent)
}

func enrichWithBillableMetric(enrichedEvent *models.EnrichedEvent, bm *models.BillableMetric) utils.Result[*models.EnrichedEvent] {
	enrichedEvent.BillableMetric = bm
	enrichedEvent.AggregationType = bm.AggregationType.String()

	if enrichedEvent.Source != models.HTTP_RUBY {
		expressionResult := evaluateExpression(enrichedEvent, bm)
		if expressionResult.Failure() {
			return FailedResult[*models.EnrichedEvent](expressionResult, "evaluate_expression", "Error evaluating custom expression")
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

func evaluateExpression(ev *models.EnrichedEvent, bm *models.BillableMetric) utils.Result[bool] {
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
