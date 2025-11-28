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

func setupProcessorTestEnv(t *testing.T) (*EventProcessor, *testProducerService, *tests.MockFlagStore, *cache.Cache) {
	logger = slog.New(slog.NewJSONHandler(os.Stdout, nil))
	slog.SetDefault(logger)

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
		NewEventEnrichmentService(memCache),
		testProducers.producers,
		flagger,
		NewCacheService(chargeCacheStore),
	)

	return processor, testProducers, &flagStore, memCache
}

func TestProcessEvent(t *testing.T) {
	t.Run("Without Billable Metric", func(t *testing.T) {
		processor, _, _, _ := setupProcessorTestEnv(t)

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
		processor, testProducers, _, memCache := setupProcessorTestEnv(t)

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

		charge := &models.Charge{
			ID:               "ch123",
			OrganizationID:   event.OrganizationID,
			PlanID:           "plan123",
			BillableMetricID: bm.ID,
			PayInAdvance:     false,
			UpdatedAt:        utils.NowNullTime(),
		}
		memCache.SetCharge(charge)

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
		processor, _, _, cache := setupProcessorTestEnv(t)

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
		processor, _, _, cache := setupProcessorTestEnv(t)

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
		processor, _, _, memCache := setupProcessorTestEnv(t)

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
		processor, testProducers, flagger, memCache := setupProcessorTestEnv(t)

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
		memCache.SetBillableMetric(bm)

		sub := &models.Subscription{
			ID:             "sub123",
			OrganizationID: &event.OrganizationID,
			ExternalID:     event.ExternalSubscriptionID,
			PlanID:         "plan_id",
		}
		memCache.SetSubscription(sub)

		charge := &models.Charge{
			ID:               "ch123",
			OrganizationID:   event.OrganizationID,
			PlanID:           "plan_id",
			BillableMetricID: bm.ID,
			UpdatedAt:        utils.NowNullTime(),
			PayInAdvance:     true,
		}
		memCache.SetCharge(charge)

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
		processor, testProducers, _, memCache := setupProcessorTestEnv(t)

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
		result := memCache.SetBillableMetric(&bm)
		require.True(t, result.Success())

		bmf1 := &models.BillableMetricFilter{
			ID:               uuid.New().String(),
			OrganizationID:   event.OrganizationID,
			BillableMetricID: bm.ID,
			Key:              "scheme",
			Values:           []string{"visa"},
		}
		result = memCache.SetBillableMetricFilter(bmf1)
		require.True(t, result.Success())

		sub := models.Subscription{
			ID:             "sub123",
			OrganizationID: &event.OrganizationID,
			ExternalID:     event.ExternalSubscriptionID,
			PlanID:         "plan_id",
		}
		result = memCache.SetSubscription(&sub)
		require.True(t, result.Success())

		charge1 := &models.Charge{
			ID:               "charge_id1",
			OrganizationID:   event.OrganizationID,
			PlanID:           "plan_id",
			BillableMetricID: bm.ID,
			UpdatedAt:        utils.NowNullTime(),
		}
		result = memCache.SetCharge(charge1)
		require.True(t, result.Success())

		chargeFilter1 := &models.ChargeFilter{
			ID:             "charge_filter_id1",
			OrganizationID: event.OrganizationID,
			ChargeID:       charge1.ID,
		}
		result = memCache.SetChargeFilter(chargeFilter1)
		require.True(t, result.Success())

		chargeFilterValue1 := &models.ChargeFilterValue{
			ID:                     uuid.New().String(),
			OrganizationID:         event.OrganizationID,
			ChargeFilterID:         chargeFilter1.ID,
			BillableMetricFilterID: bmf1.ID,
		}
		result = memCache.SetChargeFilterValue(chargeFilterValue1)
		require.True(t, result.Success())

		charge2 := &models.Charge{
			ID:               "charge_id2",
			OrganizationID:   event.OrganizationID,
			PlanID:           "plan_id",
			BillableMetricID: bm.ID,
			UpdatedAt:        utils.NowNullTime(),
		}
		result = memCache.SetCharge(charge2)
		require.True(t, result.Success())

		chargeFilter2 := &models.ChargeFilter{
			ID:             "charge_filter_id2",
			OrganizationID: event.OrganizationID,
			ChargeID:       charge2.ID,
		}
		result = memCache.SetChargeFilter(chargeFilter2)
		require.True(t, result.Success())

		chargeFilterValue2 := &models.ChargeFilterValue{
			ID:                     uuid.New().String(),
			OrganizationID:         event.OrganizationID,
			ChargeFilterID:         chargeFilter2.ID,
			BillableMetricFilterID: bmf1.ID,
		}
		result = memCache.SetChargeFilterValue(chargeFilterValue2)
		require.True(t, result.Success())

		evResult := processor.processEvent(context.Background(), &event)
		assert.True(t, evResult.Success())
		assert.Equal(t, "12.0", *evResult.Value().Value)
		assert.Equal(t, "sum", evResult.Value().AggregationType)
		assert.Equal(t, "sub123", evResult.Value().SubscriptionID)
		assert.Equal(t, "plan_id", evResult.Value().PlanID)

		// Give some time to the go routine to complete
		// TODO: Improve this by using channels in the producers methods
		time.Sleep(50 * time.Millisecond)
		assert.Equal(t, 1, testProducers.enrichedProducer.ExecutionCount)
		assert.Equal(t, 2, testProducers.enrichedExpandedProducer.ExecutionCount)
	})

	t.Run("When event source is not post processed on API and it matches no charges", func(t *testing.T) {
		processor, testProducers, _, memCache := setupProcessorTestEnv(t)

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
