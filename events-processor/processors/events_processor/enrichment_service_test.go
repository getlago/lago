package events_processor

import (
	"context"
	"log/slog"
	"sort"
	"testing"

	"github.com/getlago/lago/events-processor/cache"
	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/utils"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func setupEnrichmentTestEnv(t *testing.T) (*EventEnrichmentService, *cache.Cache) {
	ctx := context.Background()
	logger := slog.Default()
	memCache, _ := cache.NewCache(cache.CacheConfig{
		Context: ctx,
		Logger:  logger,
	})

	processor := &EventEnrichmentService{
		memCache: memCache,
	}

	return processor, memCache
}

func TestEnrichEvent(t *testing.T) {
	t.Run("Without Billable Metric", func(t *testing.T) {
		processor, _ := setupEnrichmentTestEnv(t)

		event := models.Event{
			OrganizationID:         "1a901a90-1a90-1a90-1a90-1a901a901a90",
			ExternalSubscriptionID: "sub_id",
			Code:                   "api_calls",
			Timestamp:              1741007009,
		}

		result := processor.EnrichEvent(&event)
		assert.False(t, result.Success())
		assert.Equal(t, "Key not found", result.ErrorMsg())
		assert.Equal(t, "fetch_billable_metric", result.ErrorCode())
		assert.Equal(t, "Error fetching billable metric", result.ErrorMessage())
	})

	t.Run("When event source is post processed on API and the result is successful", func(t *testing.T) {
		processor, cache := setupEnrichmentTestEnv(t)

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

		bm := &models.BillableMetric{
			ID:              "bm123",
			OrganizationID:  event.OrganizationID,
			Code:            event.Code,
			AggregationType: models.AggregationTypeSum,
			FieldName:       "api_requests",
			Expression:      "",
			CreatedAt:       utils.NowNullTime(),
			UpdatedAt:       utils.NowNullTime(),
		}
		result := cache.SetBillableMetric(bm)
		require.True(t, result.Success())

		sub := &models.Subscription{
			ID:             "sub123",
			OrganizationID: &event.OrganizationID,
			ExternalID:     event.ExternalSubscriptionID,
			PlanID:         "plan123",
		}
		result = cache.SetSubscription(sub)
		require.True(t, result.Success())

		enrichResult := processor.EnrichEvent(&event)

		assert.True(t, enrichResult.Success())
		assert.Equal(t, 1, len(enrichResult.Value()))

		eventResult := enrichResult.Value()[0]
		assert.Equal(t, "12.0", *eventResult.Value)
		assert.Equal(t, "sum", eventResult.AggregationType)
		assert.Equal(t, "sub123", eventResult.SubscriptionID)
		assert.Equal(t, "plan123", eventResult.PlanID)
	})

	t.Run("When timestamp is invalid", func(t *testing.T) {
		processor, cache := setupEnrichmentTestEnv(t)

		event := models.Event{
			OrganizationID:         "1a901a90-1a90-1a90-1a90-1a901a901a90",
			ExternalSubscriptionID: "sub_id",
			Code:                   "api_calls",
			Timestamp:              "2025-03-06T12:00:00Z",
			Source:                 "SQS",
		}

		bm := &models.BillableMetric{
			ID:              "bm123",
			OrganizationID:  event.OrganizationID,
			Code:            event.Code,
			AggregationType: models.AggregationTypeWeightedSum,
			FieldName:       "api_requests",
			Expression:      "",
			CreatedAt:       utils.NowNullTime(),
			UpdatedAt:       utils.NowNullTime(),
		}
		result := cache.SetBillableMetric(bm)
		require.True(t, result.Success())

		enrichResult := processor.EnrichEvent(&event)
		assert.False(t, enrichResult.Success())
		assert.Equal(t, "strconv.ParseFloat: parsing \"2025-03-06T12:00:00Z\": invalid syntax", enrichResult.ErrorMsg())
		assert.Equal(t, "build_enriched_event", enrichResult.ErrorCode())
		assert.Equal(t, "Error while converting event to enriched event", enrichResult.ErrorMessage())
	})

	t.Run("When expression failed to evaluate", func(t *testing.T) {
		processor, cache := setupEnrichmentTestEnv(t)

		event := models.Event{
			OrganizationID:         "1a901a90-1a90-1a90-1a90-1a901a901a90",
			ExternalSubscriptionID: "sub_id",
			Code:                   "api_calls",
			Timestamp:              "1741007009.123",
			Source:                 "SQS",
		}

		bm := &models.BillableMetric{
			ID:              "bm123",
			OrganizationID:  event.OrganizationID,
			Code:            event.Code,
			AggregationType: models.AggregationTypeWeightedSum,
			FieldName:       "api_requests",
			Expression:      "round(event.properties.value)",
			CreatedAt:       utils.NowNullTime(),
			UpdatedAt:       utils.NowNullTime(),
		}
		result := cache.SetBillableMetric(bm)
		require.True(t, result.Success())

		enrichResult := processor.EnrichEvent(&event)
		assert.False(t, enrichResult.Success())
		assert.Contains(t, enrichResult.ErrorMsg(), "failed to evaluate expr: round(event.properties.value)")
		assert.Equal(t, "evaluate_expression", enrichResult.ErrorCode())
		assert.Equal(t, "Error evaluating custom expression", enrichResult.ErrorMessage())
	})

	t.Run("With a flat filter", func(t *testing.T) {
		processor, cache := setupEnrichmentTestEnv(t)

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

		bm := &models.BillableMetric{
			ID:              "bm123",
			OrganizationID:  event.OrganizationID,
			Code:            event.Code,
			AggregationType: models.AggregationTypeWeightedSum,
			FieldName:       "api_requests",
			Expression:      "round(event.properties.value)",
			CreatedAt:       utils.NowNullTime(),
			UpdatedAt:       utils.NowNullTime(),
		}
		result := cache.SetBillableMetric(bm)
		require.True(t, result.Success())

		sub := &models.Subscription{
			ID:             "sub123",
			OrganizationID: &event.OrganizationID,
			ExternalID:     event.ExternalSubscriptionID,
			PlanID:         "plan_id",
		}
		result = cache.SetSubscription(sub)
		require.True(t, result.Success())

		enrichResult := processor.EnrichEvent(&event)
		assert.True(t, enrichResult.Success())
		assert.Equal(t, len(enrichResult.Value()), 1)

		eventResult := enrichResult.Value()[0]
		assert.Equal(t, "12", *eventResult.Value)
	})

	t.Run("With multiple flat filters", func(t *testing.T) {
		processor, cache := setupEnrichmentTestEnv(t)

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

		bm := &models.BillableMetric{
			ID:              "bm123",
			OrganizationID:  event.OrganizationID,
			Code:            event.Code,
			AggregationType: models.AggregationTypeWeightedSum,
			FieldName:       "api_requests",
			Expression:      "round(event.properties.value)",
			CreatedAt:       utils.NowNullTime(),
			UpdatedAt:       utils.NowNullTime(),
		}
		result := cache.SetBillableMetric(bm)
		require.True(t, result.Success())

		sub := &models.Subscription{
			ID:             "sub123",
			OrganizationID: &event.OrganizationID,
			ExternalID:     event.ExternalSubscriptionID,
			PlanID:         "plan_id",
		}
		result = cache.SetSubscription(sub)
		require.True(t, result.Success())

		charge1 := &models.Charge{
			ID:               "charge1",
			OrganizationID:   event.OrganizationID,
			PlanID:           "plan_id",
			BillableMetricID: bm.ID,
			UpdatedAt:        utils.NowNullTime(),
		}
		result = cache.SetCharge(charge1)
		require.True(t, result.Success())

		charge2 := &models.Charge{
			ID:               "charge2",
			OrganizationID:   event.OrganizationID,
			PlanID:           "plan_id",
			BillableMetricID: bm.ID,
			UpdatedAt:        utils.NowNullTime(),
		}
		result = cache.SetCharge(charge2)
		require.True(t, result.Success())

		enrichResult := processor.EnrichEvent(&event)
		assert.True(t, enrichResult.Success())
		assert.Equal(t, 2, len(enrichResult.Value()))

		events := enrichResult.Value()
		sort.Slice(events, func(i, j int) bool {
			return *events[i].ChargeID < *events[j].ChargeID
		})

		eventResult1 := events[0]
		assert.Equal(t, "12", *eventResult1.Value)
		assert.Equal(t, "charge1", *eventResult1.ChargeID)
		assert.Equal(t, map[string]string{}, eventResult1.GroupedBy)

		eventResult2 := events[1]
		assert.Equal(t, "12", *eventResult2.Value)
		assert.Equal(t, "charge2", *eventResult2.ChargeID)
		assert.Equal(t, map[string]string{}, eventResult2.GroupedBy)
	})

	// TODO: Rewrite this test since its not working with the new cache behavior
	// t.Run("When event source is not post process on API with a flat filter with pricing group keys", func(t *testing.T) {
	// 	cache := setupTestEnv(t)

	// 	orgID := uuid.New().String()
	// 	bmID := uuid.New().String()
	// 	extSubID := "sub_id"
	// 	bmCode := "test_metric"
	// 	planID := "plan_id"

	// 	properties := map[string]any{
	// 		"value":   "12.12",
	// 		"scheme":  "visa",
	// 		"country": "US",
	// 		"type":    "debit",
	// 	}

	// 	now := utils.NowNullTime()
	// 	event := models.Event{
	// 		OrganizationID:         orgID,
	// 		ExternalSubscriptionID: extSubID,
	// 		Code:                   bmCode,
	// 		Timestamp:              now,
	// 		Properties:             properties,
	// 		Source:                 "SQS",
	// 	}

	// 	bm := &models.BillableMetric{
	// 		ID:              bmID,
	// 		OrganizationID:  orgID,
	// 		Code:            bmCode,
	// 		AggregationType: models.AggregationTypeWeightedSum,
	// 		FieldName:       "api_requests",
	// 		Expression:      "round(event.properties.value)",
	// 		CreatedAt:       utils.NowNullTime(),
	// 		UpdatedAt:       utils.NowNullTime(),
	// 	}
	// 	result := cache.SetBillableMetric(bm)
	// 	require.True(t, result.Success())

	// 	bmf := &models.BillableMetricFilter{
	// 		ID:               "bmf123",
	// 		OrganizationID:   orgID,
	// 		BillableMetricID: bmID,
	// 		Key:              "country",
	// 		Values:           []string{"US"},
	// 	}
	// 	result = cache.SetBillableMetricFilter(bmf)
	// 	require.True(t, result.Success())

	// 	sub := &models.Subscription{
	// 		ID:             "sub123",
	// 		OrganizationID: &orgID,
	// 		ExternalID:     extSubID,
	// 		PlanID:         planID,
	// 	}
	// 	result = cache.SetSubscription(sub)
	// 	require.True(t, result.Success())

	// 	charge := &models.Charge{
	// 		ID:               "charge_id1",
	// 		OrganizationID:   orgID,
	// 		BillableMetricID: bmID,
	// 		PlanID:           planID,
	// 		UpdatedAt:        utils.NowNullTime(),
	// 		PricingGroupKeys: []string{"country", "type"},
	// 	}
	// 	result = cache.SetCharge(charge)
	// 	require.True(t, result.Success())

	// 	chargeFilter := &models.ChargeFilter{
	// 		ID:             "charge_filter_id1",
	// 		OrganizationID: orgID,
	// 		ChargeID:       charge.ID,
	// 	}
	// 	result = cache.SetChargeFilter(chargeFilter)
	// 	require.True(t, result.Success())

	// 	chargeFilterValue := &models.ChargeFilterValue{
	// 		ID:                     uuid.New().String(),
	// 		OrganizationID:         orgID,
	// 		ChargeFilterID:         chargeFilter.ID,
	// 		BillableMetricFilterID: bmf.ID,
	// 		Values:                 []string{"US"},
	// 	}
	// 	result = cache.SetChargeFilterValue(chargeFilterValue)
	// 	require.True(t, result.Success())

	// 	enrichResult := processor.EnrichEvent(&event)
	// 	assert.True(t, enrichResult.Success())
	// 	assert.Equal(t, 1, len(enrichResult.Value()))

	// 	eventResult := enrichResult.Value()[0]
	// 	assert.Equal(t, "12", *eventResult.Value)
	// 	assert.Equal(t, "charge_id1", *eventResult.ChargeID)
	// 	assert.Equal(t, map[string]string{"country": "US", "type": "debit"}, eventResult.GroupedBy)
	// })
}

func TestEvaluateExpression(t *testing.T) {
	processor, _ := setupEnrichmentTestEnv(t)

	bm := models.BillableMetric{}
	event := models.EnrichedEvent{Timestamp: 1741007009.0, Code: "foo"}
	var result utils.Result[bool]

	t.Run("Without expression", func(t *testing.T) {
		result = processor.evaluateExpression(&event, &bm)
		assert.True(t, result.Success(), "It should succeed when Billable metric does not have a custom expression")
	})

	t.Run("With an expression but without required fields", func(t *testing.T) {
		bm.Expression = "round(event.properties.value * event.properties.units)"
		bm.FieldName = "total_value"
		result = processor.evaluateExpression(&event, &bm)
		assert.False(t, result.Success())
		assert.Contains(
			t,
			result.ErrorMsg(),
			"failed to evaluate expr:",
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
