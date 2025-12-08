package events_processor

import (
	"context"
	"log/slog"
	"os"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

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

type ProcessorTestEnv struct {
	EventProcessor  *EventProcessor
	ProducerService *testProducerService
	FlagStore       *tests.MockFlagStore
	Cache           *cache.Cache
	MockedStore     *tests.MockedStore
	Delete          func()
}

func setupProcessorTestEnv(t *testing.T, useCache bool) *ProcessorTestEnv {
	logger = slog.New(slog.NewJSONHandler(os.Stdout, nil))
	slog.SetDefault(logger)

	var mockedStore *tests.MockedStore
	var delete func()
	var apiStore *models.ApiStore
	var chargeCache models.Cacher

	if !useCache {
		mockedStore, delete = tests.SetupMockStore(t)
		apiStore = models.NewApiStore(mockedStore.DB)
	}

	testProducers := setupProducers()

	chargeCache = &tests.MockCacheStore{}
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

	return &ProcessorTestEnv{
		EventProcessor:  processor,
		ProducerService: testProducers,
		FlagStore:       &flagStore,
		Cache:           memCache,
		MockedStore:     mockedStore,
		Delete:          delete,
	}
}

func TestProcessEvent_WithCache(t *testing.T) {
	t.Run("Without Billable Metric", func(t *testing.T) {
		testEnv := setupProcessorTestEnv(t, true)
		defer testEnv.Cache.Close()

		event := models.Event{
			OrganizationID:         "1a901a90-1a90-1a90-1a90-1a901a901a90",
			ExternalSubscriptionID: "sub_id",
			Code:                   "api_calls",
			Timestamp:              1741007009,
		}

		result := testEnv.EventProcessor.processEvent(context.Background(), &event)
		assert.False(t, result.Success())
		assert.Equal(t, "Key not found", result.ErrorMsg())
		assert.Equal(t, "fetch_billable_metric", result.ErrorCode())
		assert.Equal(t, "Error fetching billable metric", result.ErrorMessage())
	})

	t.Run("When event source is post processed on API", func(t *testing.T) {
		testEnv := setupProcessorTestEnv(t, true)
		defer testEnv.Cache.Close()

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
		testEnv.Cache.SetBillableMetric(&bm)

		sub := models.Subscription{
			ID:             "sub123",
			OrganizationID: &event.OrganizationID,
			ExternalID:     event.ExternalSubscriptionID,
			PlanID:         "plan123",
		}
		testEnv.Cache.SetSubscription(&sub)

		charge := &models.Charge{
			ID:               "ch123",
			OrganizationID:   event.OrganizationID,
			PlanID:           "plan123",
			BillableMetricID: bm.ID,
			PayInAdvance:     false,
			UpdatedAt:        utils.NowNullTime(),
		}
		testEnv.Cache.SetCharge(charge)

		ctx := context.Background()
		result := testEnv.EventProcessor.processEvent(ctx, &event)

		assert.True(t, result.Success())
		assert.Equal(t, "12.0", *result.Value().Value)
		assert.Equal(t, "sum", result.Value().AggregationType)
		assert.Equal(t, "sub123", result.Value().SubscriptionID)
		assert.Equal(t, "plan123", result.Value().PlanID)

		// Give some time to the go routine to complete
		// TODO: Improve this by using channels in the producers methods
		time.Sleep(50 * time.Millisecond)
		assert.Equal(t, 1, testEnv.ProducerService.enrichedProducer.ExecutionCount)
		assert.Equal(t, 1, testEnv.ProducerService.enrichedExpandedProducer.ExecutionCount)
	})

	t.Run("When event source is not post process on API when timestamp is invalid", func(t *testing.T) {
		testEnv := setupProcessorTestEnv(t, true)
		defer testEnv.Cache.Close()

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
		testEnv.Cache.SetBillableMetric(&bm)

		ctx := context.Background()
		result := testEnv.EventProcessor.processEvent(ctx, &event)
		assert.False(t, result.Success())
		assert.Equal(t, "strconv.ParseFloat: parsing \"2025-03-06T12:00:00Z\": invalid syntax", result.ErrorMsg())
		assert.Equal(t, "build_enriched_event", result.ErrorCode())
		assert.Equal(t, "Error while converting event to enriched event", result.ErrorMessage())
	})

	t.Run("When event source is not post process on API when no subscriptions are found", func(t *testing.T) {
		testEnv := setupProcessorTestEnv(t, true)
		defer testEnv.Cache.Close()

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
		testEnv.Cache.SetBillableMetric(&bm)

		result := testEnv.EventProcessor.processEvent(context.Background(), &event)
		assert.True(t, result.Success())
	})

	t.Run("When event source is not post process on API when expression failed to evaluate", func(t *testing.T) {
		testEnv := setupProcessorTestEnv(t, true)
		defer testEnv.Cache.Close()

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
			CreatedAt:       utils.NowNullTime(),
			UpdatedAt:       utils.NowNullTime(),
		}
		testEnv.Cache.SetBillableMetric(&bm)

		sub := models.Subscription{
			ID:             "sub123",
			OrganizationID: &event.OrganizationID,
			ExternalID:     event.ExternalSubscriptionID,
		}
		testEnv.Cache.SetSubscription(&sub)

		ctx := context.Background()
		result := testEnv.EventProcessor.processEvent(ctx, &event)
		assert.False(t, result.Success())
		assert.Contains(t, result.ErrorMsg(), "failed to evaluate expr: round(event.properties.value)")
		assert.Equal(t, "evaluate_expression", result.ErrorCode())
		assert.Equal(t, "Error evaluating custom expression", result.ErrorMessage())
	})

	t.Run("When event source is not post process on API and events belongs to an in advance charge", func(t *testing.T) {
		testEnv := setupProcessorTestEnv(t, true)
		defer testEnv.Cache.Close()

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
		testEnv.Cache.SetBillableMetric(bm)

		sub := &models.Subscription{
			ID:             "sub123",
			OrganizationID: &event.OrganizationID,
			ExternalID:     event.ExternalSubscriptionID,
			PlanID:         "plan_id",
		}
		testEnv.Cache.SetSubscription(sub)

		charge := &models.Charge{
			ID:               "ch123",
			OrganizationID:   event.OrganizationID,
			PlanID:           "plan_id",
			BillableMetricID: bm.ID,
			UpdatedAt:        utils.NowNullTime(),
			PayInAdvance:     true,
		}
		testEnv.Cache.SetCharge(charge)

		result := testEnv.EventProcessor.processEvent(context.Background(), &event)
		assert.True(t, result.Success())
		assert.Equal(t, "12", *result.Value().Value)

		// Give some time to the go routine to complete
		// TODO: Improve this by using channels in the producers methods
		time.Sleep(50 * time.Millisecond)
		assert.Equal(t, 1, testEnv.ProducerService.inAdvanceProducer.ExecutionCount)
		assert.Equal(t, 1, testEnv.ProducerService.enrichedProducer.ExecutionCount)
		assert.Equal(t, 1, testEnv.ProducerService.enrichedExpandedProducer.ExecutionCount)

		assert.Equal(t, 1, testEnv.FlagStore.ExecutionCount)
	})

	t.Run("When event source is not post processed on API and it matches multiple charges", func(t *testing.T) {
		testEnv := setupProcessorTestEnv(t, true)
		defer testEnv.Cache.Close()

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
		result := testEnv.Cache.SetBillableMetric(&bm)
		require.True(t, result.Success())

		bmf1 := &models.BillableMetricFilter{
			ID:               uuid.New().String(),
			OrganizationID:   event.OrganizationID,
			BillableMetricID: bm.ID,
			Key:              "scheme",
			Values:           []string{"visa"},
		}
		result = testEnv.Cache.SetBillableMetricFilter(bmf1)
		require.True(t, result.Success())

		sub := models.Subscription{
			ID:             "sub123",
			OrganizationID: &event.OrganizationID,
			ExternalID:     event.ExternalSubscriptionID,
			PlanID:         "plan_id",
		}
		result = testEnv.Cache.SetSubscription(&sub)
		require.True(t, result.Success())

		charge1 := &models.Charge{
			ID:               "charge_id1",
			OrganizationID:   event.OrganizationID,
			PlanID:           "plan_id",
			BillableMetricID: bm.ID,
			UpdatedAt:        utils.NowNullTime(),
		}
		result = testEnv.Cache.SetCharge(charge1)
		require.True(t, result.Success())

		chargeFilter1 := &models.ChargeFilter{
			ID:             "charge_filter_id1",
			OrganizationID: event.OrganizationID,
			ChargeID:       charge1.ID,
		}
		result = testEnv.Cache.SetChargeFilter(chargeFilter1)
		require.True(t, result.Success())

		chargeFilterValue1 := &models.ChargeFilterValue{
			ID:                     uuid.New().String(),
			OrganizationID:         event.OrganizationID,
			ChargeFilterID:         chargeFilter1.ID,
			BillableMetricFilterID: bmf1.ID,
		}
		result = testEnv.Cache.SetChargeFilterValue(chargeFilterValue1)
		require.True(t, result.Success())

		charge2 := &models.Charge{
			ID:               "charge_id2",
			OrganizationID:   event.OrganizationID,
			PlanID:           "plan_id",
			BillableMetricID: bm.ID,
			UpdatedAt:        utils.NowNullTime(),
		}
		result = testEnv.Cache.SetCharge(charge2)
		require.True(t, result.Success())

		chargeFilter2 := &models.ChargeFilter{
			ID:             "charge_filter_id2",
			OrganizationID: event.OrganizationID,
			ChargeID:       charge2.ID,
		}
		result = testEnv.Cache.SetChargeFilter(chargeFilter2)
		require.True(t, result.Success())

		chargeFilterValue2 := &models.ChargeFilterValue{
			ID:                     uuid.New().String(),
			OrganizationID:         event.OrganizationID,
			ChargeFilterID:         chargeFilter2.ID,
			BillableMetricFilterID: bmf1.ID,
		}
		result = testEnv.Cache.SetChargeFilterValue(chargeFilterValue2)
		require.True(t, result.Success())

		evResult := testEnv.EventProcessor.processEvent(context.Background(), &event)
		assert.True(t, evResult.Success())
		assert.Equal(t, "12.0", *evResult.Value().Value)
		assert.Equal(t, "sum", evResult.Value().AggregationType)
		assert.Equal(t, "sub123", evResult.Value().SubscriptionID)
		assert.Equal(t, "plan_id", evResult.Value().PlanID)

		// Give some time to the go routine to complete
		// TODO: Improve this by using channels in the producers methods
		time.Sleep(50 * time.Millisecond)
		assert.Equal(t, 1, testEnv.ProducerService.enrichedProducer.ExecutionCount)
		assert.Equal(t, 2, testEnv.ProducerService.enrichedExpandedProducer.ExecutionCount)
	})

	t.Run("When event source is not post processed on API and it matches no charges", func(t *testing.T) {
		testEnv := setupProcessorTestEnv(t, true)
		defer testEnv.Cache.Close()

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
		testEnv.Cache.SetBillableMetric(&bm)

		sub := models.Subscription{
			ID:             "sub123",
			OrganizationID: &event.OrganizationID,
			ExternalID:     event.ExternalSubscriptionID,
			PlanID:         "plan123",
		}
		testEnv.Cache.SetSubscription(&sub)

		result := testEnv.EventProcessor.processEvent(context.Background(), &event)
		assert.True(t, result.Success())
		assert.Equal(t, "12.0", *result.Value().Value)
		assert.Equal(t, "sum", result.Value().AggregationType)
		assert.Equal(t, "sub123", result.Value().SubscriptionID)
		assert.Equal(t, "plan123", result.Value().PlanID)

		// Give some time to the go routine to complete
		// TODO: Improve this by using channels in the producers methods
		time.Sleep(50 * time.Millisecond)
		assert.Equal(t, 1, testEnv.ProducerService.enrichedProducer.ExecutionCount)
		assert.Equal(t, 0, testEnv.ProducerService.enrichedExpandedProducer.ExecutionCount)
	})
}
