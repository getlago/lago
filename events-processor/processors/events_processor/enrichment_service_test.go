package events_processor

import (
	"context"
	"testing"
	"time"

	"github.com/getlago/lago/events-processor/cache"
	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/tests"
	"github.com/getlago/lago/events-processor/utils"
	"github.com/stretchr/testify/assert"
)

type enrichmentTestEnv struct {
	EventProcessor *EventEnrichmentService
	DataStore      DataStore
	Cleanup        func()
}

func setupEnrichmentTestEnv(t *testing.T, useCache bool) *enrichmentTestEnv {
	var memCache *cache.Cache
	var apiStore *models.ApiStore
	var dataStore DataStore
	var cleanup func()

	if useCache {
		ctx := context.Background()
		memCache, _ = cache.NewCache(cache.CacheConfig{
			Context: ctx,
		})
		dataStore = &CacheDataStore{cache: memCache, t: t}
		cleanup = func() { memCache.Close() }
	} else {
		mockedStore, deleteFunc := tests.SetupMockStore(t)
		apiStore = models.NewApiStore(mockedStore.DB)
		dataStore = &MockDataStore{mock: mockedStore, t: t}
		cleanup = deleteFunc
	}

	processor := &EventEnrichmentService{
		apiStore: apiStore,
		memCache: memCache,
	}

	return &enrichmentTestEnv{
		EventProcessor: processor,
		DataStore:      dataStore,
		Cleanup:        cleanup,
	}
}

func TestEnrichEvent(t *testing.T) {
	testModes := []struct {
		name     string
		useCache bool
	}{
		{"WithCache", true},
		{"WithoutCache", false},
	}

	for _, mode := range testModes {
		t.Run(mode.name, func(t *testing.T) {
			t.Run("Without Billable Metric", func(t *testing.T) {
				testEnv := setupEnrichmentTestEnv(t, mode.useCache)
				defer testEnv.Cleanup()

				event := models.Event{
					OrganizationID:         "1a901a90-1a90-1a90-1a90-1a901a901a90",
					ExternalSubscriptionID: "sub_id",
					Code:                   "api_calls",
					Timestamp:              1741007009,
				}

				testEnv.DataStore.ExpectBillableMetricNotFound()
				result := testEnv.EventProcessor.EnrichEvent(&event)
				assert.False(t, result.Success())
				if mode.useCache {
					assert.Equal(t, "Key not found", result.ErrorMsg())
				} else {
					assert.Equal(t, "record not found", result.ErrorMsg())
				}
				assert.Equal(t, "fetch_billable_metric", result.ErrorCode())
				assert.Equal(t, "Error fetching billable metric", result.ErrorMessage())
			})

			t.Run("When timestamp is invalid", func(t *testing.T) {
				testEnv := setupEnrichmentTestEnv(t, mode.useCache)
				defer testEnv.Cleanup()

				event := models.Event{
					OrganizationID:         "1a901a90-1a90-1a90-1a90-1a901a901a90",
					ExternalSubscriptionID: "sub_id",
					Code:                   "api_calls",
					Timestamp:              "2025-03-06 12:00:00",
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
				testEnv.DataStore.SetBillableMetric(bm)

				enrichResult := testEnv.EventProcessor.EnrichEvent(&event)
				assert.False(t, enrichResult.Success())
				assert.Equal(t, "strconv.ParseFloat: parsing \"2025-03-06 12:00:00\": invalid syntax", enrichResult.ErrorMsg())
				assert.Equal(t, "build_enriched_event", enrichResult.ErrorCode())
				assert.Equal(t, "Error while converting event to enriched event", enrichResult.ErrorMessage())
			})

			t.Run("When expression failed to evaluate", func(t *testing.T) {
				testEnv := setupEnrichmentTestEnv(t, mode.useCache)
				defer testEnv.Cleanup()

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
				testEnv.DataStore.SetBillableMetric(bm)

				enrichResult := testEnv.EventProcessor.EnrichEvent(&event)
				assert.False(t, enrichResult.Success())
				assert.Contains(t, enrichResult.ErrorMsg(), "failed to evaluate expr: round(event.properties.value)")
				assert.Equal(t, "evaluate_expression", enrichResult.ErrorCode())
				assert.Equal(t, "Error evaluating custom expression", enrichResult.ErrorMessage())
			})

			t.Run("With a recurring billable metric and no subscription active at the event timestamp", func(t *testing.T) {
				testEnv := setupEnrichmentTestEnv(t, mode.useCache)
				defer testEnv.Cleanup()

				orgID := "1a901a90-1a90-1a90-1a90-1a901a901a90"

				// Event dated 2025-03-03
				event := models.Event{
					OrganizationID:         orgID,
					ExternalSubscriptionID: "sub_id",
					Code:                   "api_calls",
					Timestamp:              1741007009.0,
					Source:                 "SQS",
				}

				bm := &models.BillableMetric{
					ID:              "bm123",
					OrganizationID:  event.OrganizationID,
					Code:            event.Code,
					AggregationType: models.AggregationTypeCount,
					Recurring:       true,
					CreatedAt:       utils.NowNullTime(),
					UpdatedAt:       utils.NowNullTime(),
				}
				testEnv.DataStore.SetBillableMetric(bm)

				// Subscription started after the event timestamp but is currently active,
				// so it is only found when falling back on time.Now().
				sub := &models.Subscription{
					ID:             "sub123",
					OrganizationID: &event.OrganizationID,
					ExternalID:     event.ExternalSubscriptionID,
					PlanID:         "plan_id",
					StartedAt:      utils.NewNullTime(time.Unix(1751000000, 0)),
				}
				// First lookup (event timestamp) misses, fallback lookup (now) hits.
				testEnv.DataStore.ExpectSubscriptionNotFound()
				testEnv.DataStore.SetSubscription(sub)

				enrichResult := testEnv.EventProcessor.EnrichEvent(&event)
				assert.True(t, enrichResult.Success())

				eventResult := enrichResult.Value()
				assert.NotNil(t, eventResult.Subscription)
				assert.Equal(t, "sub123", eventResult.SubscriptionID)
				assert.Equal(t, "plan_id", eventResult.PlanID)
			})

			t.Run("With a non-recurring billable metric and no subscription active at the event timestamp", func(t *testing.T) {
				testEnv := setupEnrichmentTestEnv(t, mode.useCache)
				defer testEnv.Cleanup()

				orgID := "1a901a90-1a90-1a90-1a90-1a901a901a90"

				event := models.Event{
					OrganizationID:         orgID,
					ExternalSubscriptionID: "sub_id",
					Code:                   "api_calls",
					Timestamp:              1741007009.0,
					Source:                 "SQS",
				}

				bm := &models.BillableMetric{
					ID:              "bm123",
					OrganizationID:  event.OrganizationID,
					Code:            event.Code,
					AggregationType: models.AggregationTypeCount,
					Recurring:       false,
					CreatedAt:       utils.NowNullTime(),
					UpdatedAt:       utils.NowNullTime(),
				}
				testEnv.DataStore.SetBillableMetric(bm)

				// A currently active subscription exists but started after the event
				// timestamp. Since the metric is not recurring, no fallback happens and
				// the event is enriched without a subscription (a single lookup, at the
				// event timestamp, that misses).
				if mode.useCache {
					// In cache mode the timestamp filtering excludes the subscription
					// because it started after the event timestamp.
					sub := &models.Subscription{
						ID:             "sub123",
						OrganizationID: &event.OrganizationID,
						ExternalID:     event.ExternalSubscriptionID,
						PlanID:         "plan_id",
						StartedAt:      utils.NewNullTime(time.Unix(1751000000, 0)),
					}
					testEnv.DataStore.SetSubscription(sub)
				} else {
					testEnv.DataStore.ExpectSubscriptionNotFound()
				}

				enrichResult := testEnv.EventProcessor.EnrichEvent(&event)
				assert.True(t, enrichResult.Success())

				eventResult := enrichResult.Value()
				assert.Nil(t, eventResult.Subscription)
				assert.Equal(t, "", eventResult.SubscriptionID)
			})
		})
	}
}

func TestEvaluateExpression(t *testing.T) {
	testEnv := setupEnrichmentTestEnv(t, true)
	defer testEnv.Cleanup()

	bm := models.BillableMetric{}
	event := models.EnrichedEvent{Timestamp: 1741007009.0, Code: "foo"}
	var result utils.Result[bool]

	t.Run("Without expression", func(t *testing.T) {
		result = testEnv.EventProcessor.evaluateExpression(&event, &bm)
		assert.True(t, result.Success(), "It should succeed when Billable metric does not have a custom expression")
	})

	t.Run("With an expression but without required fields", func(t *testing.T) {
		bm.Expression = "round(event.properties.value * event.properties.units)"
		bm.FieldName = "total_value"
		result = testEnv.EventProcessor.evaluateExpression(&event, &bm)
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
		result = testEnv.EventProcessor.evaluateExpression(&event, &bm)
		assert.True(t, result.Success())
		assert.Equal(t, "36", event.Properties["total_value"])
	})

	t.Run("With a float timestamp", func(t *testing.T) {
		event.Timestamp = 1741007009.123

		result = testEnv.EventProcessor.evaluateExpression(&event, &bm)
		assert.True(t, result.Success())
		assert.Equal(t, "36", event.Properties["total_value"])
	})
}

func TestHasPayInAdvanceCharge(t *testing.T) {
	testModes := []struct {
		name     string
		useCache bool
	}{
		{"WithCache", true},
		{"WithoutCache", false},
	}

	for _, mode := range testModes {
		t.Run(mode.name, func(t *testing.T) {
			t.Run("Without billable metric", func(t *testing.T) {
				testEnv := setupEnrichmentTestEnv(t, mode.useCache)
				defer testEnv.Cleanup()

				enrichedEvent := &models.EnrichedEvent{
					OrganizationID: "org-123",
					PlanID:         "plan-123",
				}

				result := testEnv.EventProcessor.HasPayInAdvanceCharge(enrichedEvent)
				assert.True(t, result.Success())
				assert.False(t, result.Value())
			})

			t.Run("Without plan", func(t *testing.T) {
				testEnv := setupEnrichmentTestEnv(t, mode.useCache)
				defer testEnv.Cleanup()

				enrichedEvent := &models.EnrichedEvent{
					OrganizationID: "org-123",
					BillableMetric: &models.BillableMetric{ID: "bm-123"},
				}

				result := testEnv.EventProcessor.HasPayInAdvanceCharge(enrichedEvent)
				assert.True(t, result.Success())
				assert.False(t, result.Value())
			})

			t.Run("With a charge charged in advance", func(t *testing.T) {
				testEnv := setupEnrichmentTestEnv(t, mode.useCache)
				defer testEnv.Cleanup()

				testEnv.DataStore.SetCharge(&models.Charge{
					ID:               "charge-123",
					OrganizationID:   "org-123",
					PlanID:           "plan-123",
					BillableMetricID: "bm-123",
					PayInAdvance:     true,
					CreatedAt:        utils.NowNullTime(),
					UpdatedAt:        utils.NowNullTime(),
				})

				enrichedEvent := &models.EnrichedEvent{
					OrganizationID: "org-123",
					PlanID:         "plan-123",
					BillableMetric: &models.BillableMetric{ID: "bm-123"},
				}

				result := testEnv.EventProcessor.HasPayInAdvanceCharge(enrichedEvent)
				assert.True(t, result.Success())
				assert.True(t, result.Value())
			})

			t.Run("Without any charge charged in advance", func(t *testing.T) {
				testEnv := setupEnrichmentTestEnv(t, mode.useCache)
				defer testEnv.Cleanup()

				testEnv.DataStore.SetCharge(&models.Charge{
					ID:               "charge-123",
					OrganizationID:   "org-123",
					PlanID:           "plan-123",
					BillableMetricID: "bm-123",
					PayInAdvance:     false,
					CreatedAt:        utils.NowNullTime(),
					UpdatedAt:        utils.NowNullTime(),
				})

				enrichedEvent := &models.EnrichedEvent{
					OrganizationID: "org-123",
					PlanID:         "plan-123",
					BillableMetric: &models.BillableMetric{ID: "bm-123"},
				}

				result := testEnv.EventProcessor.HasPayInAdvanceCharge(enrichedEvent)
				assert.True(t, result.Success())
				assert.False(t, result.Value())
			})
		})
	}
}
