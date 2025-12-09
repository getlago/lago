package events_processor

import (
	"context"
	"log/slog"
	"sort"
	"testing"
	"time"

	"github.com/getlago/lago/events-processor/cache"
	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/tests"
	"github.com/getlago/lago/events-processor/utils"
	"github.com/google/uuid"
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
		logger := slog.Default()
		memCache, _ = cache.NewCache(cache.CacheConfig{
			Context: ctx,
			Logger:  logger,
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
				testEnv.DataStore.SetBillableMetric(bm)

				enrichResult := testEnv.EventProcessor.EnrichEvent(&event)
				assert.False(t, enrichResult.Success())
				assert.Equal(t, "strconv.ParseFloat: parsing \"2025-03-06T12:00:00Z\": invalid syntax", enrichResult.ErrorMsg())
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

			t.Run("With a flat filter", func(t *testing.T) {
				testEnv := setupEnrichmentTestEnv(t, mode.useCache)
				defer testEnv.Cleanup()

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
				testEnv.DataStore.SetBillableMetric(bm)

				sub := &models.Subscription{
					ID:             "sub123",
					OrganizationID: &event.OrganizationID,
					ExternalID:     event.ExternalSubscriptionID,
					PlanID:         "plan_id",
				}
				testEnv.DataStore.SetSubscription(sub)
				testEnv.DataStore.SetFlatFilters([]*models.FlatFilter{})

				enrichResult := testEnv.EventProcessor.EnrichEvent(&event)
				assert.True(t, enrichResult.Success())
				assert.Equal(t, len(enrichResult.Value()), 1)

				eventResult := enrichResult.Value()[0]
				assert.Equal(t, "12", *eventResult.Value)
			})

			t.Run("With multiple flat filters", func(t *testing.T) {
				testEnv := setupEnrichmentTestEnv(t, mode.useCache)
				defer testEnv.Cleanup()

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
				testEnv.DataStore.SetBillableMetric(bm)

				sub := &models.Subscription{
					ID:             "sub123",
					OrganizationID: &event.OrganizationID,
					ExternalID:     event.ExternalSubscriptionID,
					PlanID:         "plan_id",
				}
				testEnv.DataStore.SetSubscription(sub)

				if mode.useCache {
					charges := []*models.Charge{
						{
							ID:               "charge1",
							OrganizationID:   event.OrganizationID,
							PlanID:           "plan_id",
							BillableMetricID: bm.ID,
							UpdatedAt:        utils.NowNullTime(),
						},
						{
							ID:               "charge2",
							OrganizationID:   event.OrganizationID,
							PlanID:           "plan_id",
							BillableMetricID: bm.ID,
							UpdatedAt:        utils.NowNullTime(),
						},
					}
					for _, charge := range charges {
						testEnv.DataStore.SetCharge(charge)
					}
				} else {
					now1 := time.Now()
					now2 := now1.Add(time.Hour)
					flat_filters := []*models.FlatFilter{
						{
							OrganizationID:        "org_id",
							BillableMetricCode:    "api_calls",
							PlanID:                "plan_id",
							ChargeID:              "charge1",
							ChargeUpdatedAt:       now1,
							ChargeFilterID:        utils.StringPtr("charge_filter_id1"),
							ChargeFilterUpdatedAt: &now1,
							Filters:               &models.FlatFilterValues{"scheme": []string{"visa"}},
						},
						{
							OrganizationID:        "org_id",
							BillableMetricCode:    "api_calls",
							PlanID:                "plan_id",
							ChargeID:              "charge2",
							ChargeUpdatedAt:       now2,
							ChargeFilterID:        utils.StringPtr("charge_filter_id2"),
							ChargeFilterUpdatedAt: &now2,
							Filters:               &models.FlatFilterValues{"scheme": []string{"visa"}},
						},
					}
					testEnv.DataStore.SetFlatFilters(flat_filters)
				}

				enrichResult := testEnv.EventProcessor.EnrichEvent(&event)
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

			t.Run("With a flat filter with pricing group keys", func(t *testing.T) {
				testEnv := setupEnrichmentTestEnv(t, mode.useCache)
				defer testEnv.Cleanup()

				orgID := uuid.New().String()
				bmID := uuid.New().String()
				extSubID := "sub_id"
				bmCode := "test_metric"
				planID := "plan_id"

				properties := map[string]any{
					"value":   "12.12",
					"scheme":  "visa",
					"country": "US",
					"type":    "debit",
				}

				event := models.Event{
					OrganizationID:         orgID,
					ExternalSubscriptionID: extSubID,
					Code:                   bmCode,
					Timestamp:              1741007009.0,
					Properties:             properties,
					Source:                 "SQS",
				}

				bm := &models.BillableMetric{
					ID:              bmID,
					OrganizationID:  orgID,
					Code:            bmCode,
					AggregationType: models.AggregationTypeWeightedSum,
					FieldName:       "api_requests",
					Expression:      "round(event.properties.value)",
					CreatedAt:       utils.NowNullTime(),
					UpdatedAt:       utils.NowNullTime(),
				}
				testEnv.DataStore.SetBillableMetric(bm)

				bmf := &models.BillableMetricFilter{
					ID:               "bmf123",
					OrganizationID:   orgID,
					BillableMetricID: bmID,
					Key:              "country",
					Values:           []string{"US"},
				}
				testEnv.DataStore.SetBillableMetricFilter(bmf)

				sub := &models.Subscription{
					ID:             "sub123",
					OrganizationID: &orgID,
					ExternalID:     extSubID,
					PlanID:         planID,
				}
				testEnv.DataStore.SetSubscription(sub)

				if mode.useCache {
					charge := &models.Charge{
						ID:               "charge_id1",
						OrganizationID:   orgID,
						BillableMetricID: bmID,
						PlanID:           planID,
						UpdatedAt:        utils.NowNullTime(),
						PricingGroupKeys: []string{"country", "type"},
					}
					testEnv.DataStore.SetCharge(charge)

					chargeFilter := &models.ChargeFilter{
						ID:               "charge_filter_id1",
						OrganizationID:   orgID,
						ChargeID:         charge.ID,
						PricingGroupKeys: []string{"country", "type"},
					}
					testEnv.DataStore.SetChargeFilter(chargeFilter)

					chargeFilterValue := &models.ChargeFilterValue{
						ID:                     uuid.New().String(),
						OrganizationID:         orgID,
						ChargeFilterID:         chargeFilter.ID,
						BillableMetricFilterID: bmf.ID,
						Values:                 []string{"US"},
					}
					testEnv.DataStore.SetChargeFilterValue(chargeFilterValue)
				} else {
					now := time.Now()
					charge_filter_id := "charge_filter_id"
					flatFilter := &models.FlatFilter{
						OrganizationID:        "org_id",
						BillableMetricCode:    "api_calls",
						PlanID:                "plan_id",
						ChargeID:              "charge_id1",
						ChargeUpdatedAt:       now,
						ChargeFilterID:        &charge_filter_id,
						ChargeFilterUpdatedAt: &now,
						Filters:               &models.FlatFilterValues{"scheme": []string{"visa"}},
						PricingGroupKeys:      []string{"country", "type"},
					}
					testEnv.DataStore.SetFlatFilters([]*models.FlatFilter{flatFilter})
				}

				enrichResult := testEnv.EventProcessor.EnrichEvent(&event)
				assert.True(t, enrichResult.Success())
				assert.Equal(t, 1, len(enrichResult.Value()))

				eventResult := enrichResult.Value()[0]
				assert.Equal(t, "12", *eventResult.Value)
				assert.Equal(t, "charge_id1", *eventResult.ChargeID)
				assert.Equal(t, map[string]string{"country": "US", "type": "debit"}, eventResult.GroupedBy)
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
