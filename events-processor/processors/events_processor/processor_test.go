package events_processor

import (
	"context"
	"log/slog"
	"os"
	"testing"
	"time"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/stretchr/testify/assert"

	"github.com/getlago/lago/events-processor/cache"
	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/utils"

	"github.com/getlago/lago/events-processor/tests"
)

type testProducerService struct {
	enrichedProducer         *tests.MockMessageProducer
	enrichedExpandedProducer *tests.MockMessageProducer
	inAdvanceProducer        *tests.MockMessageProducer
	deadLetterProducer       *tests.MockMessageProducer
	producers                *EventProducerService
}

func setupProducers() *testProducerService {
	enrichedProducer := tests.MockMessageProducer{}
	enrichedExpandedProducer := tests.MockMessageProducer{}
	inAdvanceProducer := tests.MockMessageProducer{}
	deadLetterProducer := tests.MockMessageProducer{}

	logger = slog.New(slog.NewJSONHandler(os.Stdout, nil))
	slog.SetDefault(logger)

	producers := NewEventProducerService(
		&enrichedProducer,
		&enrichedExpandedProducer,
		&inAdvanceProducer,
		&deadLetterProducer,
		logger,
	)

	return &testProducerService{
		enrichedProducer:         &enrichedProducer,
		enrichedExpandedProducer: &enrichedExpandedProducer,
		inAdvanceProducer:        &inAdvanceProducer,
		deadLetterProducer:       &deadLetterProducer,
		producers:                producers,
	}
}

func setupProcessorTestEnv(t *testing.T) (*EventProcessor, *tests.MockedStore, *testProducerService, *tests.MockFlagStore, *cache.Cache, func()) {
	logger = slog.New(slog.NewJSONHandler(os.Stdout, nil))
	slog.SetDefault(logger)

	mockedStore, delete := tests.SetupMockStore(t)
	apiStore := models.NewApiStore(mockedStore.DB)

	testProducers := setupProducers()

	cacheStore := tests.MockCacheStore{}
	var chargeCache models.Cacher = &cacheStore
	chargeCacheStore := models.NewChargeCache(&chargeCache)

	flagStore := tests.MockFlagStore{}
	flagger := NewSubscriptionRefreshService(&flagStore)

	ctx := context.Background()
	memCache, _ := cache.NewCache(cache.CacheConfig{
		Context: ctx,
		Logger:  logger,
	})

	processor := NewEventProcessor(
		logger,
		NewEventEnrichmentService(apiStore, memCache),
		testProducers.producers,
		flagger,
		NewCacheService(chargeCacheStore),
	)

	return processor, mockedStore, testProducers, &flagStore, memCache, delete
}

func mockFlatFiltersLookup(mock *tests.MockedStore, filters []*models.FlatFilter) {
	columns := []string{
		"organization_id",
		"billable_metric_code",
		"pay_in_advance",
		"plan_id",
		"charge_id",
		"charge_updated_at",
		"charge_filter_id",
		"charge_filter_updated_at",
		"filters",
		"pricing_group_keys",
	}

	rows := sqlmock.NewRows(columns)

	for _, filter := range filters {
		rows.AddRow(
			filter.OrganizationID,
			filter.BillableMetricCode,
			filter.PayInAdvance,
			filter.PlanID,
			filter.ChargeID,
			filter.ChargeUpdatedAt,
			filter.ChargeFilterID,
			filter.ChargeFilterUpdatedAt,
			filter.Filters,
			filter.PricingGroupKeys,
		)
	}

	mock.SQLMock.ExpectQuery(".* FROM \"flat_filters\".*").WillReturnRows(rows)
}

func TestProcessEvent(t *testing.T) {
	t.Run("Without Billable Metric", func(t *testing.T) {
		processor, _, _, _, _, delete := setupProcessorTestEnv(t)
		defer delete()

		event := models.Event{
			OrganizationID:         "1a901a90-1a90-1a90-1a90-1a901a901a90",
			ExternalSubscriptionID: "sub_id",
			Code:                   "api_calls",
			Timestamp:              1741007009,
		}

		result := processor.processEvent(context.Background(), &event)
		assert.False(t, result.Success())
		assert.Equal(t, "Key not found", result.ErrorMsg())
		assert.Equal(t, "fetch_billable_metric", result.ErrorCode())
		assert.Equal(t, "Error fetching billable metric", result.ErrorMessage())
	})

	t.Run("When event source is post processed on API", func(t *testing.T) {
		processor, mockedStore, testProducers, _, memCache, delete := setupProcessorTestEnv(t)
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
			CreatedAt:       utils.NowNullTime(),
			UpdatedAt:       utils.NowNullTime(),
		}
		memCache.SetBillableMetric(&bm)

		sub := models.Subscription{
			ID:             "sub123",
			OrganizationID: &event.OrganizationID,
			ExternalID:     event.ExternalSubscriptionID,
			PlanID:         "plan123",
		}
		memCache.SetSubscription(&sub)

		mockFlatFiltersLookup(mockedStore, []*models.FlatFilter{
			{
				OrganizationID:     event.OrganizationID,
				BillableMetricCode: event.Code,
				PlanID:             "plan_id",
				ChargeID:           "charge_idxx",
				ChargeUpdatedAt:    time.Now(),
				PayInAdvance:       true,
			},
		})

		ctx := context.Background()
		result := processor.processEvent(ctx, &event)

		assert.True(t, result.Success())
		assert.Equal(t, "12.0", *result.Value().Value)
		assert.Equal(t, "sum", result.Value().AggregationType)
		assert.Equal(t, "sub123", result.Value().SubscriptionID)
		assert.Equal(t, "plan123", result.Value().PlanID)

		// Give some time to the go routine to complete
		// TODO: Improve this by using channels in the producers methods
		time.Sleep(50 * time.Millisecond)
		assert.Equal(t, 1, testProducers.enrichedProducer.ExecutionCount)
		assert.Equal(t, 1, testProducers.enrichedExpandedProducer.ExecutionCount)
	})

	t.Run("When event source is not post process on API when timestamp is invalid", func(t *testing.T) {
		processor, _, _, _, cache, delete := setupProcessorTestEnv(t)
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
			CreatedAt:       utils.NowNullTime(),
			UpdatedAt:       utils.NowNullTime(),
		}
		cache.SetBillableMetric(&bm)

		ctx := context.Background()
		result := processor.processEvent(ctx, &event)
		assert.False(t, result.Success())
		assert.Equal(t, "strconv.ParseFloat: parsing \"2025-03-06T12:00:00Z\": invalid syntax", result.ErrorMsg())
		assert.Equal(t, "build_enriched_event", result.ErrorCode())
		assert.Equal(t, "Error while converting event to enriched event", result.ErrorMessage())
	})

	t.Run("When event source is not post process on API when no subscriptions are found", func(t *testing.T) {
		processor, _, _, _, cache, delete := setupProcessorTestEnv(t)
		defer delete()

		event := models.Event{
			OrganizationID:         "1a901a90-1a90-1a90-1a90-1a901a901a90",
			ExternalSubscriptionID: "sub_id",
			Code:                   "api_calls",
			Timestamp:              1741007009,
			Source:                 "SQS",
		}

		bm := models.BillableMetric{
			ID:              "bm123",
			OrganizationID:  event.OrganizationID,
			Code:            event.Code,
			AggregationType: models.AggregationTypeWeightedSum,
			FieldName:       "api_requests",
			Expression:      "",
			CreatedAt:       utils.NowNullTime(),
			UpdatedAt:       utils.NowNullTime(),
		}
		cache.SetBillableMetric(&bm)

		result := processor.processEvent(context.Background(), &event)
		assert.True(t, result.Success())
	})

	t.Run("When event source is not post process on API when expression failed to evaluate", func(t *testing.T) {
		processor, _, _, _, memCache, delete := setupProcessorTestEnv(t)
		defer delete()

		// properties := map[string]any{
		// 	"value": "12.12",
		// }

		event := models.Event{
			OrganizationID:         "1a901a90-1a90-1a90-1a90-1a901a901a90",
			ExternalSubscriptionID: "sub_id",
			Code:                   "api_calls",
			Timestamp:              "1741007009.123",
			//Properties:             properties,
			Source: "SQS",
		}

		bm := models.BillableMetric{
			ID:              "bm123",
			OrganizationID:  event.OrganizationID,
			Code:            event.Code,
			AggregationType: models.AggregationTypeWeightedSum,
			FieldName:       "api_requests",
			Expression:      "round(event.properties.value)",
			CreatedAt:       utils.NowNullTime(),
			UpdatedAt:       utils.NowNullTime(),
		}
		memCache.SetBillableMetric(&bm)

		sub := models.Subscription{
			ID:             "sub123",
			OrganizationID: &event.OrganizationID,
			ExternalID:     event.ExternalSubscriptionID,
		}
		memCache.SetSubscription(&sub)

		ctx := context.Background()
		result := processor.processEvent(ctx, &event)
		assert.False(t, result.Success())
		assert.Contains(t, result.ErrorMsg(), "failed to evaluate expr: round(event.properties.value)")
		assert.Equal(t, "evaluate_expression", result.ErrorCode())
		assert.Equal(t, "Error evaluating custom expression", result.ErrorMessage())
	})

	t.Run("When event source is not post process on API and events belongs to an in advance charge", func(t *testing.T) {
		processor, mockedStore, testProducers, flagger, memCache, delete := setupProcessorTestEnv(t)
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
			CreatedAt:       utils.NowNullTime(),
			UpdatedAt:       utils.NowNullTime(),
		}
		memCache.SetBillableMetric(&bm)

		sub := models.Subscription{
			ID:             "sub123",
			OrganizationID: &event.OrganizationID,
			ExternalID:     event.ExternalSubscriptionID,
			PlanID:         "plan_id",
		}
		memCache.SetSubscription(&sub)

		now := time.Now()

		mockFlatFiltersLookup(mockedStore, []*models.FlatFilter{
			{
				OrganizationID:     "org_id",
				BillableMetricCode: "api_call",
				PlanID:             "plan_id",
				ChargeID:           "charge_idxx",
				ChargeUpdatedAt:    now,
				PayInAdvance:       true,
			},
		})

		result := processor.processEvent(context.Background(), &event)
		assert.True(t, result.Success())
		assert.Equal(t, "12", *result.Value().Value)

		// Give some time to the go routine to complete
		// TODO: Improve this by using channels in the producers methods
		time.Sleep(50 * time.Millisecond)
		assert.Equal(t, 1, testProducers.inAdvanceProducer.ExecutionCount)
		assert.Equal(t, 1, testProducers.enrichedProducer.ExecutionCount)
		assert.Equal(t, 1, testProducers.enrichedExpandedProducer.ExecutionCount)

		assert.Equal(t, 1, flagger.ExecutionCount)
	})

	t.Run("When event source is not post processed on API and it matches multiple charges", func(t *testing.T) {
		processor, mockedStore, testProducers, _, memCache, delete := setupProcessorTestEnv(t)
		defer delete()

		properties := map[string]any{
			"api_requests": "12.0",
		}

		event := models.Event{
			OrganizationID:         "1a901a90-1a90-1a90-1a90-1a901a901a90",
			ExternalSubscriptionID: "sub_id",
			Code:                   "api_calls",
			Timestamp:              1741007009,
			Properties:             properties,
			Source:                 "SQS",
		}

		bm := models.BillableMetric{
			ID:              "bm123",
			OrganizationID:  event.OrganizationID,
			Code:            event.Code,
			AggregationType: models.AggregationTypeSum,
			FieldName:       "api_requests",
			Expression:      "",
			CreatedAt:       utils.NowNullTime(),
			UpdatedAt:       utils.NowNullTime(),
		}
		memCache.SetBillableMetric(&bm)

		sub := models.Subscription{
			ID:             "sub123",
			OrganizationID: &event.OrganizationID,
			ExternalID:     event.ExternalSubscriptionID,
			PlanID:         "plan123",
		}
		memCache.SetSubscription(&sub)

		now := time.Now()

		flatFilter1 := &models.FlatFilter{
			OrganizationID:        "org_id",
			BillableMetricCode:    "api_calls",
			PlanID:                "plan_id",
			ChargeID:              "charge_id1",
			ChargeUpdatedAt:       now,
			ChargeFilterID:        utils.StringPtr("charge_filter_id1"),
			ChargeFilterUpdatedAt: &now,
			Filters:               &models.FlatFilterValues{"scheme": []string{"visa"}},
		}

		flatFilter2 := &models.FlatFilter{
			OrganizationID:        "org_id",
			BillableMetricCode:    "api_calls",
			PlanID:                "plan_id",
			ChargeID:              "charge_id2",
			ChargeUpdatedAt:       now,
			ChargeFilterID:        utils.StringPtr("charge_filter_id2"),
			ChargeFilterUpdatedAt: &now,
			Filters:               &models.FlatFilterValues{"scheme": []string{"visa"}},
		}
		mockFlatFiltersLookup(mockedStore, []*models.FlatFilter{flatFilter1, flatFilter2})

		result := processor.processEvent(context.Background(), &event)

		assert.True(t, result.Success())
		assert.Equal(t, "12.0", *result.Value().Value)
		assert.Equal(t, "sum", result.Value().AggregationType)
		assert.Equal(t, "sub123", result.Value().SubscriptionID)
		assert.Equal(t, "plan123", result.Value().PlanID)

		// Give some time to the go routine to complete
		// TODO: Improve this by using channels in the producers methods
		time.Sleep(50 * time.Millisecond)
		assert.Equal(t, 1, testProducers.enrichedProducer.ExecutionCount)
		assert.Equal(t, 2, testProducers.enrichedExpandedProducer.ExecutionCount)
	})

	t.Run("When event source is not post processed on API and it matches no charges", func(t *testing.T) {
		processor, mockedStore, testProducers, _, memCache, delete := setupProcessorTestEnv(t)
		defer delete()

		properties := map[string]any{
			"api_requests": "12.0",
		}

		event := models.Event{
			OrganizationID:         "1a901a90-1a90-1a90-1a90-1a901a901a90",
			ExternalSubscriptionID: "sub_id",
			Code:                   "api_calls",
			Timestamp:              1741007009,
			Properties:             properties,
			Source:                 "SQS",
		}

		bm := models.BillableMetric{
			ID:              "bm123",
			OrganizationID:  event.OrganizationID,
			Code:            event.Code,
			AggregationType: models.AggregationTypeSum,
			FieldName:       "api_requests",
			Expression:      "",
			CreatedAt:       utils.NowNullTime(),
			UpdatedAt:       utils.NowNullTime(),
		}
		memCache.SetBillableMetric(&bm)

		sub := models.Subscription{
			ID:             "sub123",
			OrganizationID: &event.OrganizationID,
			ExternalID:     event.ExternalSubscriptionID,
			PlanID:         "plan123",
		}
		memCache.SetSubscription(&sub)

		mockFlatFiltersLookup(mockedStore, []*models.FlatFilter{})

		result := processor.processEvent(context.Background(), &event)
		assert.True(t, result.Success())
		assert.Equal(t, "12.0", *result.Value().Value)
		assert.Equal(t, "sum", result.Value().AggregationType)
		assert.Equal(t, "sub123", result.Value().SubscriptionID)
		assert.Equal(t, "plan123", result.Value().PlanID)

		// Give some time to the go routine to complete
		// TODO: Improve this by using channels in the producers methods
		time.Sleep(50 * time.Millisecond)
		assert.Equal(t, 1, testProducers.enrichedProducer.ExecutionCount)
		assert.Equal(t, 0, testProducers.enrichedExpandedProducer.ExecutionCount)
	})
}
