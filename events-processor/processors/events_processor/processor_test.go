package events_processor

import (
	"context"
	"log/slog"
	"os"
	"testing"
	"time"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"gorm.io/gorm"

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
	producerService          *EventProducerService
}

func setupProducers() *testProducerService {
	enrichedProducer := tests.MockMessageProducer{}
	enrichedExpandedProducer := tests.MockMessageProducer{}
	inAdvanceProducer := tests.MockMessageProducer{}
	deadLetterProducer := tests.MockMessageProducer{}

	logger = slog.New(slog.NewJSONHandler(os.Stdout, nil))
	slog.SetDefault(logger)

	producerService := NewEventProducerService(
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
		producerService:          producerService,
	}
}

// DataStore abstracts cache vs DB mock setup
type DataStore interface {
	SetBillableMetric(bm *models.BillableMetric)
	SetSubscription(sub *models.Subscription)
	SetCharge(charge *models.Charge)
	SetFlatFilters(filters []*models.FlatFilter)
	SetBillableMetricFilter(bmf *models.BillableMetricFilter)
	SetChargeFilter(cf *models.ChargeFilter)
	SetChargeFilterValue(cfv *models.ChargeFilterValue)
	ExpectSubscriptionNotFound()
	ExpectSubscriptionError()
	ExpectBillableMetricNotFound()
}

// CacheDataStore wraps cache for test setup
type CacheDataStore struct {
	cache *cache.Cache
	t     *testing.T
}

func (s *CacheDataStore) SetBillableMetric(bm *models.BillableMetric) {
	result := s.cache.SetBillableMetric(bm)
	require.True(s.t, result.Success())
}

func (s *CacheDataStore) SetSubscription(sub *models.Subscription) {
	result := s.cache.SetSubscription(sub)
	require.True(s.t, result.Success())
}

func (s *CacheDataStore) SetCharge(charge *models.Charge) {
	result := s.cache.SetCharge(charge)
	require.True(s.t, result.Success())
}

func (s *CacheDataStore) SetBillableMetricFilter(bmf *models.BillableMetricFilter) {
	result := s.cache.SetBillableMetricFilter(bmf)
	require.True(s.t, result.Success())
}

func (s *CacheDataStore) SetChargeFilter(cf *models.ChargeFilter) {
	result := s.cache.SetChargeFilter(cf)
	require.True(s.t, result.Success())
}

func (s *CacheDataStore) SetChargeFilterValue(cfv *models.ChargeFilterValue) {
	result := s.cache.SetChargeFilterValue(cfv)
	require.True(s.t, result.Success())
}

func (s *CacheDataStore) SetFlatFilters(filters []*models.FlatFilter) {}
func (s *CacheDataStore) ExpectSubscriptionNotFound()                 {}
func (s *CacheDataStore) ExpectSubscriptionError()                    {}
func (s *CacheDataStore) ExpectBillableMetricNotFound()               {}

// MockDataStore wraps SQL mock for test setup
type MockDataStore struct {
	mock *tests.MockedStore
	t    *testing.T
}

func (s *MockDataStore) SetBillableMetric(bm *models.BillableMetric) {
	columns := []string{"id", "organization_id", "code", "aggregation_type", "field_name", "expression", "created_at", "updated_at", "deleted_at"}
	rows := sqlmock.NewRows(columns).
		AddRow(bm.ID, bm.OrganizationID, bm.Code, bm.AggregationType, bm.FieldName, bm.Expression, bm.CreatedAt, bm.UpdatedAt, bm.DeletedAt)
	s.mock.SQLMock.ExpectQuery("SELECT \\* FROM \"billable_metrics\".*").WillReturnRows(rows)
}

func (s *MockDataStore) SetSubscription(sub *models.Subscription) {
	columns := []string{"id", "external_id", "plan_id", "created_at", "updated_at", "terminated_at"}
	rows := sqlmock.NewRows(columns).
		AddRow(sub.ID, sub.ExternalID, sub.PlanID, sub.CreatedAt, sub.UpdatedAt, sub.TerminatedAt)
	s.mock.SQLMock.ExpectQuery(".* FROM \"subscriptions\".*").WillReturnRows(rows)
}

func (s *MockDataStore) SetFlatFilters(filters []*models.FlatFilter) {
	columns := []string{
		"organization_id", "billable_metric_code", "pay_in_advance", "plan_id",
		"charge_id", "charge_updated_at", "charge_filter_id", "charge_filter_updated_at",
		"filters", "pricing_group_keys",
	}
	rows := sqlmock.NewRows(columns)
	for _, filter := range filters {
		rows.AddRow(
			filter.OrganizationID, filter.BillableMetricCode, filter.PayInAdvance, filter.PlanID,
			filter.ChargeID, filter.ChargeUpdatedAt, filter.ChargeFilterID, filter.ChargeFilterUpdatedAt,
			filter.Filters, filter.PricingGroupKeys,
		)
	}
	s.mock.SQLMock.ExpectQuery(".* FROM \"flat_filters\".*").WillReturnRows(rows)
}

func (s *MockDataStore) ExpectSubscriptionNotFound() {
	s.mock.SQLMock.ExpectQuery(".* FROM \"subscriptions\"").WillReturnError(gorm.ErrRecordNotFound)
}

func (s *MockDataStore) ExpectSubscriptionError() {
	s.mock.SQLMock.ExpectQuery(".* FROM \"subscriptions\"").WillReturnError(gorm.ErrNotImplemented)
}

func (s *MockDataStore) ExpectBillableMetricNotFound() {
	s.mock.SQLMock.ExpectQuery(".*").WillReturnError(gorm.ErrRecordNotFound)
}

func (s *MockDataStore) SetCharge(charge *models.Charge)                          {}
func (s *MockDataStore) SetBillableMetricFilter(bmf *models.BillableMetricFilter) {}
func (s *MockDataStore) SetChargeFilter(cf *models.ChargeFilter)                  {}
func (s *MockDataStore) SetChargeFilterValue(cfv *models.ChargeFilterValue)       {}

type ProcessorTestEnv struct {
	EventProcessor *EventProcessor
	Producers      *testProducerService
	FlagStore      *tests.MockFlagStore
	DataStore      DataStore
	Cleanup        func()
}

func setupProcessorTestEnv(t *testing.T, useCache bool) *ProcessorTestEnv {
	logger = slog.New(slog.NewJSONHandler(os.Stdout, nil))
	slog.SetDefault(logger)

	var chargeCache models.Cacher
	var memCache *cache.Cache
	var apiStore *models.ApiStore
	var dataStore DataStore
	var cleanup func()

	testProducers := setupProducers()
	chargeCache = &tests.MockCacheStore{}
	chargeCacheStore := models.NewChargeCache(&chargeCache)
	flagStore := tests.MockFlagStore{}
	flagger := NewSubscriptionRefreshService(&flagStore)

	if useCache {
		ctx := context.Background()
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

	processor := NewEventProcessor(
		logger,
		NewEventEnrichmentService(apiStore, memCache),
		testProducers.producerService,
		flagger,
		NewCacheService(chargeCacheStore),
	)

	return &ProcessorTestEnv{
		EventProcessor: processor,
		Producers:      testProducers,
		FlagStore:      &flagStore,
		DataStore:      dataStore,
		Cleanup:        cleanup,
	}
}

func TestProcessEvent(t *testing.T) {
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
				testEnv := setupProcessorTestEnv(t, mode.useCache)
				defer testEnv.Cleanup()

				testEnv.DataStore.ExpectBillableMetricNotFound()

				event := models.Event{
					OrganizationID:         "1a901a90-1a90-1a90-1a90-1a901a901a90",
					ExternalSubscriptionID: "sub_id",
					Code:                   "api_calls",
					Timestamp:              1741007009,
				}

				result := testEnv.EventProcessor.processEvent(context.Background(), &event)
				assert.False(t, result.Success())
				assert.Equal(t, "fetch_billable_metric", result.ErrorCode())
			})
		})

		t.Run("When event source is post processed on API", func(t *testing.T) {
			testEnv := setupProcessorTestEnv(t, mode.useCache)
			defer testEnv.Cleanup()

			event := models.Event{
				OrganizationID:         "1a901a90-1a90-1a90-1a90-1a901a901a90",
				ExternalSubscriptionID: "sub_id",
				Code:                   "api_calls",
				Timestamp:              1741007009,
				Source:                 models.HTTP_RUBY,
				Properties:             map[string]any{"api_requests": "12.0"},
				SourceMetadata:         &models.SourceMetadata{ApiPostProcess: true},
			}

			bm := &models.BillableMetric{
				ID:              "bm123",
				OrganizationID:  event.OrganizationID,
				Code:            event.Code,
				AggregationType: models.AggregationTypeSum,
				FieldName:       "api_requests",
				CreatedAt:       utils.NowNullTime(),
				UpdatedAt:       utils.NowNullTime(),
			}
			testEnv.DataStore.SetBillableMetric(bm)

			sub := &models.Subscription{
				ID:             "sub123",
				OrganizationID: &event.OrganizationID,
				ExternalID:     event.ExternalSubscriptionID,
				PlanID:         "plan123",
			}
			testEnv.DataStore.SetSubscription(sub)

			charge := &models.Charge{
				ID:               "ch123",
				OrganizationID:   event.OrganizationID,
				PlanID:           "plan123",
				BillableMetricID: bm.ID,
				PayInAdvance:     false,
				UpdatedAt:        utils.NowNullTime(),
			}
			testEnv.DataStore.SetCharge(charge)
			testEnv.DataStore.SetFlatFilters([]*models.FlatFilter{{
				OrganizationID:     event.OrganizationID,
				BillableMetricCode: event.Code,
				PlanID:             "plan123",
				ChargeID:           "ch123",
				ChargeUpdatedAt:    time.Now(),
				PayInAdvance:       false,
			}})

			result := testEnv.EventProcessor.processEvent(context.Background(), &event)

			assert.True(t, result.Success())
			assert.Equal(t, "12.0", *result.Value().Value)
			assert.Equal(t, "sum", result.Value().AggregationType)
			assert.Equal(t, "sub123", result.Value().SubscriptionID)

			time.Sleep(50 * time.Millisecond)
			assert.Equal(t, 1, testEnv.Producers.enrichedProducer.ExecutionCount)
			assert.Equal(t, 1, testEnv.Producers.enrichedExpandedProducer.ExecutionCount)
		})

		t.Run("When event source is not post process on API when timestamp is invalid", func(t *testing.T) {
			testEnv := setupProcessorTestEnv(t, mode.useCache)
			defer testEnv.Cleanup()

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
			testEnv.DataStore.SetBillableMetric(&bm)

			ctx := context.Background()
			result := testEnv.EventProcessor.processEvent(ctx, &event)
			assert.False(t, result.Success())
			assert.Equal(t, "strconv.ParseFloat: parsing \"2025-03-06T12:00:00Z\": invalid syntax", result.ErrorMsg())
			assert.Equal(t, "build_enriched_event", result.ErrorCode())
			assert.Equal(t, "Error while converting event to enriched event", result.ErrorMessage())
		})

		t.Run("When event source is not post process on API when no subscriptions are found", func(t *testing.T) {
			testEnv := setupProcessorTestEnv(t, mode.useCache)
			defer testEnv.Cleanup()

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
			testEnv.DataStore.SetBillableMetric(&bm)
			testEnv.DataStore.ExpectSubscriptionNotFound()

			result := testEnv.EventProcessor.processEvent(context.Background(), &event)
			assert.True(t, result.Success())
		})

		t.Run("When event source is not post process on API when expression failed to evaluate", func(t *testing.T) {
			testEnv := setupProcessorTestEnv(t, mode.useCache)
			defer testEnv.Cleanup()

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
			testEnv.DataStore.SetBillableMetric(&bm)

			sub := models.Subscription{
				ID:             "sub123",
				OrganizationID: &event.OrganizationID,
				ExternalID:     event.ExternalSubscriptionID,
			}
			testEnv.DataStore.SetSubscription(&sub)

			ctx := context.Background()
			result := testEnv.EventProcessor.processEvent(ctx, &event)
			assert.False(t, result.Success())
			assert.Contains(t, result.ErrorMsg(), "failed to evaluate expr: round(event.properties.value)")
			assert.Equal(t, "evaluate_expression", result.ErrorCode())
			assert.Equal(t, "Error evaluating custom expression", result.ErrorMessage())
		})

		t.Run("When event source is not post process on API and events belongs to an in advance charge", func(t *testing.T) {
			testEnv := setupProcessorTestEnv(t, mode.useCache)
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

			charge := &models.Charge{
				ID:               "ch123",
				OrganizationID:   event.OrganizationID,
				PlanID:           "plan_id",
				BillableMetricID: bm.ID,
				UpdatedAt:        utils.NowNullTime(),
				PayInAdvance:     true,
			}
			testEnv.DataStore.SetCharge(charge)

			flatFilters := []*models.FlatFilter{
				{
					OrganizationID:     "org_id",
					BillableMetricCode: "api_call",
					PlanID:             "plan_id",
					ChargeID:           "ch123",
					ChargeUpdatedAt:    utils.NowNullTime().Time,
					PayInAdvance:       true,
				},
			}
			testEnv.DataStore.SetFlatFilters(flatFilters)

			result := testEnv.EventProcessor.processEvent(context.Background(), &event)
			assert.True(t, result.Success())
			assert.Equal(t, "12", *result.Value().Value)

			// Give some time to the go routine to complete
			// TODO: Improve this by using channels in the producers methods
			time.Sleep(50 * time.Millisecond)
			assert.Equal(t, 1, testEnv.Producers.inAdvanceProducer.ExecutionCount)
			assert.Equal(t, 1, testEnv.Producers.enrichedProducer.ExecutionCount)
			assert.Equal(t, 1, testEnv.Producers.enrichedExpandedProducer.ExecutionCount)

			assert.Equal(t, 1, testEnv.FlagStore.ExecutionCount)
		})

		t.Run("When event source is not post processed on API and it matches multiple charges", func(t *testing.T) {
			testEnv := setupProcessorTestEnv(t, mode.useCache)
			defer testEnv.Cleanup()

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
			testEnv.DataStore.SetBillableMetric(&bm)

			bmf1 := &models.BillableMetricFilter{
				ID:               uuid.New().String(),
				OrganizationID:   event.OrganizationID,
				BillableMetricID: bm.ID,
				Key:              "scheme",
				Values:           []string{"visa"},
			}
			testEnv.DataStore.SetBillableMetricFilter(bmf1)

			sub := models.Subscription{
				ID:             "sub123",
				OrganizationID: &event.OrganizationID,
				ExternalID:     event.ExternalSubscriptionID,
				PlanID:         "plan_id",
			}
			testEnv.DataStore.SetSubscription(&sub)

			if mode.useCache {
				charges := []*models.Charge{
					{
						ID:               "charge_id1",
						OrganizationID:   event.OrganizationID,
						PlanID:           "plan_id",
						BillableMetricID: bm.ID,
						UpdatedAt:        utils.NowNullTime(),
					},
					{
						ID:               "charge_id2",
						OrganizationID:   event.OrganizationID,
						PlanID:           "plan_id",
						BillableMetricID: bm.ID,
						UpdatedAt:        utils.NowNullTime(),
					},
				}
				for _, charge := range charges {
					testEnv.DataStore.SetCharge(charge)
				}

				charge_filters := []*models.ChargeFilter{
					{
						ID:             "charge_filter_id1",
						OrganizationID: event.OrganizationID,
						ChargeID:       charges[0].ID,
					},
					{
						ID:             "charge_filter_id2",
						OrganizationID: event.OrganizationID,
						ChargeID:       charges[1].ID,
					},
				}
				for _, cf := range charge_filters {
					testEnv.DataStore.SetChargeFilter(cf)
				}

				charge_filter_values := []*models.ChargeFilterValue{
					{
						ID:                     uuid.New().String(),
						OrganizationID:         event.OrganizationID,
						ChargeFilterID:         charge_filters[0].ID,
						BillableMetricFilterID: bmf1.ID,
					},
					{
						ID:                     uuid.New().String(),
						OrganizationID:         event.OrganizationID,
						ChargeFilterID:         charge_filters[1].ID,
						BillableMetricFilterID: bmf1.ID,
					},
				}
				for _, cfv := range charge_filter_values {
					testEnv.DataStore.SetChargeFilterValue(cfv)
				}
			} else {
				now := time.Now()
				flat_filters := []*models.FlatFilter{
					{
						OrganizationID:        "org_id",
						BillableMetricCode:    "api_calls",
						PlanID:                "plan_id",
						ChargeID:              "charge_id1",
						ChargeUpdatedAt:       now,
						ChargeFilterID:        utils.StringPtr("charge_filter_id1"),
						ChargeFilterUpdatedAt: &now,
						Filters:               &models.FlatFilterValues{"scheme": []string{"visa"}},
					},
					{
						OrganizationID:        "org_id",
						BillableMetricCode:    "api_calls",
						PlanID:                "plan_id",
						ChargeID:              "charge_id2",
						ChargeUpdatedAt:       now,
						ChargeFilterID:        utils.StringPtr("charge_filter_id2"),
						ChargeFilterUpdatedAt: &now,
						Filters:               &models.FlatFilterValues{"scheme": []string{"visa"}},
					},
				}
				testEnv.DataStore.SetFlatFilters(flat_filters)
			}

			evResult := testEnv.EventProcessor.processEvent(context.Background(), &event)
			assert.True(t, evResult.Success())
			assert.Equal(t, "12.0", *evResult.Value().Value)
			assert.Equal(t, "sum", evResult.Value().AggregationType)
			assert.Equal(t, "sub123", evResult.Value().SubscriptionID)
			assert.Equal(t, "plan_id", evResult.Value().PlanID)

			// Give some time to the go routine to complete
			// TODO: Improve this by using channels in the producers methods
			time.Sleep(50 * time.Millisecond)
			assert.Equal(t, 1, testEnv.Producers.enrichedProducer.ExecutionCount)
			assert.Equal(t, 2, testEnv.Producers.enrichedExpandedProducer.ExecutionCount)
		})

		t.Run("When event source is not post processed on API and it matches no charges", func(t *testing.T) {
			testEnv := setupProcessorTestEnv(t, true)
			defer testEnv.Cleanup()

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
			testEnv.DataStore.SetBillableMetric(&bm)

			sub := models.Subscription{
				ID:             "sub123",
				OrganizationID: &event.OrganizationID,
				ExternalID:     event.ExternalSubscriptionID,
				PlanID:         "plan123",
			}
			testEnv.DataStore.SetSubscription(&sub)

			result := testEnv.EventProcessor.processEvent(context.Background(), &event)
			assert.True(t, result.Success())
			assert.Equal(t, "12.0", *result.Value().Value)
			assert.Equal(t, "sum", result.Value().AggregationType)
			assert.Equal(t, "sub123", result.Value().SubscriptionID)
			assert.Equal(t, "plan123", result.Value().PlanID)

			// Give some time to the go routine to complete
			// TODO: Improve this by using channels in the producers methods
			time.Sleep(50 * time.Millisecond)
			assert.Equal(t, 1, testEnv.Producers.enrichedProducer.ExecutionCount)
			assert.Equal(t, 0, testEnv.Producers.enrichedExpandedProducer.ExecutionCount)
		})
	}
}
