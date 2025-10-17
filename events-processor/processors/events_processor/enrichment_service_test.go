package events_processor

import (
	"sort"
	"testing"
	"time"

	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/tests"
	"github.com/getlago/lago/events-processor/utils"
	"github.com/stretchr/testify/assert"
	"gorm.io/gorm"
)

func setupEnrichmentTestEnv(t *testing.T) (*EventEnrichmentService, *tests.MockedStore, func()) {
	mockedStore, delete := tests.SetupMockStore(t)
	apiStore := models.NewApiStore(mockedStore.DB)

	processor := &EventEnrichmentService{
		apiStore: apiStore,
	}

	return processor, mockedStore, delete
}

func TestEnrichEvent(t *testing.T) {
	t.Run("Without Billable Metric", func(t *testing.T) {
		processor, mockedStore, delete := setupEnrichmentTestEnv(t)
		defer delete()

		event := models.Event{
			OrganizationID:         "1a901a90-1a90-1a90-1a90-1a901a901a90",
			ExternalSubscriptionID: "sub_id",
			Code:                   "api_calls",
			Timestamp:              1741007009,
		}

		mockedStore.SQLMock.ExpectQuery(".*").WillReturnError(gorm.ErrRecordNotFound)

		result := processor.EnrichEvent(&event)
		assert.False(t, result.Success())
		assert.Equal(t, "record not found", result.ErrorMsg())
		assert.Equal(t, "fetch_billable_metric", result.ErrorCode())
		assert.Equal(t, "Error fetching billable metric", result.ErrorMessage())
	})

	t.Run("When event source is post processed on API and the result is successful", func(t *testing.T) {
		processor, mockedStore, delete := setupEnrichmentTestEnv(t)
		defer delete()

		properties := map[string]any{
			"api_requests": "12.0",
		}

		event := models.Event{
			OrganizationID:         "1a901a90-1a90-1a90-1a90-1a901a901a90",
			ExternalSubscriptionID: "sub_id",
			Code:                   "api_calls",
			Timestamp:              1741007009,
			Source:                 models.HTTP_RUBY,
			Properties:             properties,
			SourceMetadata: &models.SourceMetadata{
				ApiPostProcess: true,
			},
		}

		bm := models.BillableMetric{
			ID:              "bm123",
			OrganizationID:  event.OrganizationID,
			Code:            event.Code,
			AggregationType: models.AggregationTypeSum,
			FieldName:       "api_requests",
			Expression:      "",
			CreatedAt:       time.Now(),
			UpdatedAt:       time.Now(),
		}
		mockBmLookup(mockedStore, &bm)

		sub := models.Subscription{ID: "sub123", PlanID: "plan123"}
		mockSubscriptionLookup(mockedStore, &sub)

		result := processor.EnrichEvent(&event)

		assert.True(t, result.Success())
		assert.Equal(t, 1, len(result.Value()))

		eventResult := result.Value()[0]
		assert.Equal(t, "12.0", *eventResult.Value)
		assert.Equal(t, "sum", eventResult.AggregationType)
		assert.Equal(t, "sub123", eventResult.SubscriptionID)
		assert.Equal(t, "plan123", eventResult.PlanID)
	})

	t.Run("When timestamp is invalid", func(t *testing.T) {
		processor, mockedStore, delete := setupEnrichmentTestEnv(t)
		defer delete()

		event := models.Event{
			OrganizationID:         "1a901a90-1a90-1a90-1a90-1a901a901a90",
			ExternalSubscriptionID: "sub_id",
			Code:                   "api_calls",
			Timestamp:              "2025-03-06T12:00:00Z",
			Source:                 "SQS",
		}

		bm := models.BillableMetric{
			ID:              "bm123",
			OrganizationID:  event.OrganizationID,
			Code:            event.Code,
			AggregationType: models.AggregationTypeWeightedSum,
			FieldName:       "api_requests",
			Expression:      "",
			CreatedAt:       time.Now(),
			UpdatedAt:       time.Now(),
		}
		mockBmLookup(mockedStore, &bm)

		result := processor.EnrichEvent(&event)
		assert.False(t, result.Success())
		assert.Equal(t, "strconv.ParseFloat: parsing \"2025-03-06T12:00:00Z\": invalid syntax", result.ErrorMsg())
		assert.Equal(t, "build_enriched_event", result.ErrorCode())
		assert.Equal(t, "Error while converting event to enriched event", result.ErrorMessage())
	})

	t.Run("When expression failed to evaluate", func(t *testing.T) {
		processor, mockedStore, delete := setupEnrichmentTestEnv(t)
		defer delete()

		event := models.Event{
			OrganizationID:         "1a901a90-1a90-1a90-1a90-1a901a901a90",
			ExternalSubscriptionID: "sub_id",
			Code:                   "api_calls",
			Timestamp:              "1741007009.123",
			Source:                 "SQS",
		}

		bm := models.BillableMetric{
			ID:              "bm123",
			OrganizationID:  event.OrganizationID,
			Code:            event.Code,
			AggregationType: models.AggregationTypeWeightedSum,
			FieldName:       "api_requests",
			Expression:      "round(event.properties.value)",
			CreatedAt:       time.Now(),
			UpdatedAt:       time.Now(),
		}
		mockBmLookup(mockedStore, &bm)

		result := processor.EnrichEvent(&event)
		assert.False(t, result.Success())
		assert.Contains(t, result.ErrorMsg(), "Failed to evaluate expr: round(event.properties.value)")
		assert.Equal(t, "evaluate_expression", result.ErrorCode())
		assert.Equal(t, "Error evaluating custom expression", result.ErrorMessage())
	})

	t.Run("When event source is not post process on API", func(t *testing.T) {
		processor, mockedStore, delete := setupEnrichmentTestEnv(t)
		defer delete()

		properties := map[string]any{
			"value": "12.12",
		}

		event := models.Event{
			OrganizationID:         "1a901a90-1a90-1a90-1a90-1a901a901a90",
			ExternalSubscriptionID: "sub_id",
			Code:                   "api_calls",
			Timestamp:              1741007009.0,
			Properties:             properties,
			Source:                 "SQS",
		}

		bm := models.BillableMetric{
			ID:              "bm123",
			OrganizationID:  event.OrganizationID,
			Code:            event.Code,
			AggregationType: models.AggregationTypeWeightedSum,
			FieldName:       "api_requests",
			Expression:      "round(event.properties.value)",
			CreatedAt:       time.Now(),
			UpdatedAt:       time.Now(),
		}
		mockBmLookup(mockedStore, &bm)

		sub := models.Subscription{ID: "sub123"}
		mockSubscriptionLookup(mockedStore, &sub)
		mockFlatFiltersLookup(mockedStore, []*models.FlatFilter{})

		result := processor.EnrichEvent(&event)
		assert.True(t, result.Success())
		assert.Equal(t, len(result.Value()), 1)

		eventResult := result.Value()[0]
		assert.Equal(t, "12", *eventResult.Value)
	})

	t.Run("When event source is not post process on API with multiple flat filters", func(t *testing.T) {
		processor, mockedStore, delete := setupEnrichmentTestEnv(t)
		defer delete()

		properties := map[string]any{
			"value":  "12.12",
			"scheme": "visa",
		}

		event := models.Event{
			OrganizationID:         "1a901a90-1a90-1a90-1a90-1a901a901a90",
			ExternalSubscriptionID: "sub_id",
			Code:                   "api_calls",
			Timestamp:              1741007009.0,
			Properties:             properties,
			Source:                 "SQS",
		}

		bm := models.BillableMetric{
			ID:              "bm123",
			OrganizationID:  event.OrganizationID,
			Code:            event.Code,
			AggregationType: models.AggregationTypeWeightedSum,
			FieldName:       "api_requests",
			Expression:      "round(event.properties.value)",
			CreatedAt:       time.Now(),
			UpdatedAt:       time.Now(),
		}
		mockBmLookup(mockedStore, &bm)

		sub := models.Subscription{ID: "sub123"}
		mockSubscriptionLookup(mockedStore, &sub)

		now1 := time.Now()
		flatFilter1 := &models.FlatFilter{
			OrganizationID:        "org_id",
			BillableMetricCode:    "api_calls",
			PlanID:                "plan_id",
			ChargeID:              "charge_id1",
			ChargeUpdatedAt:       now1,
			ChargeFilterID:        utils.StringPtr("charge_filter_id1"),
			ChargeFilterUpdatedAt: &now1,
			Filters:               &models.FlatFilterValues{"scheme": []string{"visa"}},
		}

		now2 := now1.Add(time.Hour)
		flatFilter2 := &models.FlatFilter{
			OrganizationID:        "org_id",
			BillableMetricCode:    "api_calls",
			PlanID:                "plan_id",
			ChargeID:              "charge_id2",
			ChargeUpdatedAt:       now2,
			ChargeFilterID:        utils.StringPtr("charge_filter_id2"),
			ChargeFilterUpdatedAt: &now2,
			Filters:               &models.FlatFilterValues{"scheme": []string{"visa"}},
		}
		mockFlatFiltersLookup(mockedStore, []*models.FlatFilter{flatFilter1, flatFilter2})

		result := processor.EnrichEvent(&event)
		assert.True(t, result.Success())
		assert.Equal(t, 2, len(result.Value()))

		events := result.Value()
		sort.Slice(events, func(i, j int) bool {
			return *events[i].ChargeID < *events[j].ChargeID
		})

		eventResult1 := events[0]
		assert.Equal(t, "12", *eventResult1.Value)
		assert.Equal(t, "charge_id1", *eventResult1.ChargeID)
		assert.Equal(t, map[string]string{}, eventResult1.GroupedBy)

		eventResult2 := events[1]
		assert.Equal(t, "12", *eventResult2.Value)
		assert.Equal(t, "charge_id2", *eventResult2.ChargeID)
		assert.Equal(t, map[string]string{}, eventResult2.GroupedBy)
	})

	t.Run("When event source is not post process on API with a flat filter with pricing group keys", func(t *testing.T) {
		processor, mockedStore, delete := setupEnrichmentTestEnv(t)
		defer delete()

		properties := map[string]any{
			"value":   "12.12",
			"scheme":  "visa",
			"country": "US",
			"type":    "debit",
		}

		event := models.Event{
			OrganizationID:         "1a901a90-1a90-1a90-1a90-1a901a901a90",
			ExternalSubscriptionID: "sub_id",
			Code:                   "api_calls",
			Timestamp:              1741007009.0,
			Properties:             properties,
			Source:                 "SQS",
		}

		bm := models.BillableMetric{
			ID:              "bm123",
			OrganizationID:  event.OrganizationID,
			Code:            event.Code,
			AggregationType: models.AggregationTypeWeightedSum,
			FieldName:       "api_requests",
			Expression:      "round(event.properties.value)",
			CreatedAt:       time.Now(),
			UpdatedAt:       time.Now(),
		}
		mockBmLookup(mockedStore, &bm)

		sub := models.Subscription{ID: "sub123"}
		mockSubscriptionLookup(mockedStore, &sub)

		now := time.Now()
		chargeFilterId := "charge_filter_id"

		flatFilter := &models.FlatFilter{
			OrganizationID:        "org_id",
			BillableMetricCode:    "api_calls",
			PlanID:                "plan_id",
			ChargeID:              "charge_id1",
			ChargeUpdatedAt:       now,
			ChargeFilterID:        &chargeFilterId,
			ChargeFilterUpdatedAt: &now,
			Filters:               &models.FlatFilterValues{"scheme": []string{"visa"}},
			PricingGroupKeys:      []string{"country", "type"},
		}
		mockFlatFiltersLookup(mockedStore, []*models.FlatFilter{flatFilter})

		result := processor.EnrichEvent(&event)
		assert.True(t, result.Success())
		assert.Equal(t, 1, len(result.Value()))

		eventResult := result.Value()[0]
		assert.Equal(t, "12", *eventResult.Value)
		assert.Equal(t, "charge_id1", *eventResult.ChargeID)
		assert.Equal(t, map[string]string{"country": "US", "type": "debit"}, eventResult.GroupedBy)
	})
}

func TestEvaluateExpression(t *testing.T) {
	processor, _, delete := setupEnrichmentTestEnv(t)
	defer delete()

	bm := models.BillableMetric{}
	event := models.EnrichedEvent{Timestamp: 1741007009.0, Code: "foo"}
	var result utils.Result[bool]

	t.Run("Without expression", func(t *testing.T) {
		result = processor.evaluateExpression(&event, &bm)
		assert.True(t, result.Success(), "It should succeed when Billable metric does not have a custom expression")
	})

	t.Run("With an expression but witout required fields", func(t *testing.T) {
		bm.Expression = "round(event.properties.value * event.properties.units)"
		bm.FieldName = "total_value"
		result = processor.evaluateExpression(&event, &bm)
		assert.False(t, result.Success())
		assert.Contains(
			t,
			result.ErrorMsg(),
			"Failed to evaluate expr:",
			"It should fail when the event does not hold the required fields",
		)
	})

	t.Run("With an expression and with required fields", func(t *testing.T) {
		properties := map[string]any{
			"value": "12.0",
			"units": 3,
		}
		event.Properties = properties
		result = processor.evaluateExpression(&event, &bm)
		assert.True(t, result.Success())
		assert.Equal(t, "36", event.Properties["total_value"])
	})

	t.Run("With a float timestamp", func(t *testing.T) {
		event.Timestamp = 1741007009.123

		result = processor.evaluateExpression(&event, &bm)
		assert.True(t, result.Success())
		assert.Equal(t, "36", event.Properties["total_value"])
	})
}
