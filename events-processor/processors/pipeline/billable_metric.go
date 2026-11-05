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

// MeteredEvent is an enriched event of either pipeline, as billable metric
// enrichment fills it.
type MeteredEvent interface {
	GetSource() string
	GetProperties() map[string]any
	SetBillableMetric(bm *models.BillableMetric)
	SetValue(value *string)
}

func (e BillableMetricEnricher) Enrich(event *models.Event) utils.Result[*models.EnrichedEvent] {
	enrichedEventResult := event.ToEnrichedEvent()
	if enrichedEventResult.Failure() {
		return FailedResult[*models.EnrichedEvent](enrichedEventResult, "build_enriched_event", "Error while converting event to enriched event")
	}

	return enrich(e, enrichedEventResult.Value(), event.OrganizationID, event.Code)
}

func (e BillableMetricEnricher) EnrichProductEvent(event *models.ProductEvent) utils.Result[*models.ProductEnrichedEvent] {
	enrichedEventResult := event.ToProductEnrichedEvent()
	if enrichedEventResult.Failure() {
		return FailedResult[*models.ProductEnrichedEvent](enrichedEventResult, "build_enriched_event", "Error while converting event to enriched event")
	}

	return enrich(e, enrichedEventResult.Value(), event.OrganizationID, event.Code)
}

func enrich[T MeteredEvent](e BillableMetricEnricher, enrichedEvent T, organizationID string, code string) utils.Result[T] {
	var bmResult utils.Result[*models.BillableMetric]

	if e.memCache != nil {
		bmResult = e.memCache.GetBillableMetric(organizationID, code)
	} else {
		bmResult = e.apiStore.FetchBillableMetric(organizationID, code)
	}
	if bmResult.Failure() {
		return FailedResult[T](bmResult, "fetch_billable_metric", "Error fetching billable metric")
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

func enrichWithBillableMetric[T MeteredEvent](enrichedEvent T, bm *models.BillableMetric) utils.Result[T] {
	enrichedEvent.SetBillableMetric(bm)

	if enrichedEvent.GetSource() != models.HTTP_RUBY {
		expressionResult := evaluateExpression(enrichedEvent, bm)
		if expressionResult.Failure() {
			return FailedResult[T](expressionResult, "evaluate_expression", "Error evaluating custom expression")
		}
	}

	if bm.AggregationType == models.AggregationTypeCount {
		enrichedEvent.SetValue(utils.StringPtr("1"))
	} else {
		var value = fmt.Sprintf("%v", enrichedEvent.GetProperties()[bm.FieldName])
		enrichedEvent.SetValue(&value)
	}

	return utils.SuccessResult(enrichedEvent)
}

func evaluateExpression(ev MeteredEvent, bm *models.BillableMetric) utils.Result[bool] {
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
		ev.GetProperties()[bm.FieldName] = *result
	} else {
		return utils.
			FailedBoolResult(fmt.Errorf("failed to evaluate expr: %s with json: %s", bm.Expression, eventJsonString)).
			NonRetryable()
	}

	return utils.SuccessResult(true)
}
