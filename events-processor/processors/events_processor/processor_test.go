package events_processor

import (
	"context"
	"encoding/json"
	"testing"
	"time"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/twmb/franz-go/pkg/kgo"
	"gorm.io/gorm"

	"github.com/getlago/lago/events-processor/cache"
	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/utils"

	"github.com/getlago/lago/events-processor/tests"
)

type testProducerService struct {
	enrichedProducer        *tests.MockMessageProducer
	inAdvanceProducer       *tests.MockMessageProducer
	deadLetterProducer      *tests.MockMessageProducer
	catalogEnrichedProducer *tests.MockMessageProducer
	producerService         *EventProducerService
}

func setupProducers() *testProducerService {
	enrichedProducer := tests.MockMessageProducer{}
	inAdvanceProducer := tests.MockMessageProducer{}
	deadLetterProducer := tests.MockMessageProducer{}
	catalogEnrichedProducer := tests.MockMessageProducer{}

	producerService := NewEventProducerService(
		&enrichedProducer,
		&inAdvanceProducer,
		&deadLetterProducer,
	).WithCatalogEnrichedProducer(&catalogEnrichedProducer)

	return &testProducerService{
		enrichedProducer:        &enrichedProducer,
		inAdvanceProducer:       &inAdvanceProducer,
		deadLetterProducer:      &deadLetterProducer,
		catalogEnrichedProducer: &catalogEnrichedProducer,
		producerService:         producerService,
	}
}

// DataStore abstracts cache vs DB mock setup
type DataStore interface {
	SetBillableMetric(bm *models.BillableMetric)
	SetSubscription(sub *models.Subscription)
	SetCharge(charge *models.Charge)
	SetContract(contract *models.Contract)
	SetAdvanceRateCard(organizationID, contractID, billableMetricID string, advance bool)
	ExpectContractNotFound()
	ExpectContractError()
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

func (s *CacheDataStore) SetContract(contract *models.Contract) {
	result := s.cache.SetContract(contract)
	require.True(s.t, result.Success())
}

// SetAdvanceRateCard attaches to the contract a rate card on a metered product of
// the billable metric, billed in advance or in arrears.
func (s *CacheDataStore) SetAdvanceRateCard(organizationID, contractID, billableMetricID string, advance bool) {
	billingTiming := "arrears"
	if advance {
		billingTiming = models.RateCardBillingTimingAdvance
	}

	require.True(s.t, s.cache.SetContractRateCard(&models.ContractRateCard{
		ID: "crc123", OrganizationID: organizationID, ContractID: contractID, RateCardID: "rc123",
	}).Success())
	require.True(s.t, s.cache.SetRateCard(&models.RateCard{
		ID: "rc123", OrganizationID: organizationID, ProductID: "product123", BillingTiming: billingTiming,
	}).Success())
	require.True(s.t, s.cache.SetProduct(&models.Product{
		ID: "product123", OrganizationID: organizationID, BillableMetricID: &billableMetricID, ProductType: models.ProductTypeMetered,
	}).Success())
}

func (s *CacheDataStore) ExpectContractNotFound()       {}
func (s *CacheDataStore) ExpectContractError()          {}
func (s *CacheDataStore) ExpectSubscriptionNotFound()   {}
func (s *CacheDataStore) ExpectSubscriptionError()      {}
func (s *CacheDataStore) ExpectBillableMetricNotFound() {}

// MockDataStore wraps SQL mock for test setup
type MockDataStore struct {
	mock *tests.MockedStore
	t    *testing.T
}

func (s *MockDataStore) SetBillableMetric(bm *models.BillableMetric) {
	columns := []string{"id", "organization_id", "code", "aggregation_type", "recurring", "field_name", "expression", "created_at", "updated_at", "deleted_at"}
	rows := sqlmock.NewRows(columns).
		AddRow(bm.ID, bm.OrganizationID, bm.Code, bm.AggregationType, bm.Recurring, bm.FieldName, bm.Expression, bm.CreatedAt, bm.UpdatedAt, bm.DeletedAt)
	s.mock.SQLMock.ExpectQuery("SELECT \\* FROM \"billable_metrics\".*").WillReturnRows(rows)
}

func (s *MockDataStore) SetSubscription(sub *models.Subscription) {
	columns := []string{"id", "external_id", "plan_id", "created_at", "updated_at", "terminated_at"}
	rows := sqlmock.NewRows(columns).
		AddRow(sub.ID, sub.ExternalID, sub.PlanID, sub.CreatedAt, sub.UpdatedAt, sub.TerminatedAt)
	s.mock.SQLMock.ExpectQuery(".* FROM \"subscriptions\".*").WillReturnRows(rows)
}

// SetCharge registers the pay in advance charge lookup. The mock does not evaluate the WHERE
// clause, so the charge is only returned when it is actually charged in advance.
func (s *MockDataStore) SetCharge(charge *models.Charge) {
	rows := sqlmock.NewRows([]string{"id"})
	if charge.PayInAdvance {
		rows.AddRow(charge.ID)
	}
	s.mock.SQLMock.ExpectQuery(".* FROM \"charges\".*").WillReturnRows(rows)
}

func (s *MockDataStore) SetContract(contract *models.Contract) {
	columns := []string{"id", "external_id", "status", "created_at", "updated_at", "started_at", "terminated_at", "canceled_at"}
	rows := sqlmock.NewRows(columns).
		AddRow(contract.ID, contract.ExternalID, contract.Status, contract.CreatedAt, contract.UpdatedAt, contract.StartedAt, contract.TerminatedAt, contract.CanceledAt)
	s.mock.SQLMock.ExpectQuery(".* FROM \"contracts\".*").WillReturnRows(rows)
}

// SetAdvanceRateCard registers the advance rate card lookup. The mock does not
// evaluate the WHERE clause, so a row is only returned for an advance card.
func (s *MockDataStore) SetAdvanceRateCard(_, _, _ string, advance bool) {
	rows := sqlmock.NewRows([]string{"id"})
	if advance {
		rows.AddRow("crc123")
	}
	s.mock.SQLMock.ExpectQuery(".* FROM \"contract_rate_cards\".*").WillReturnRows(rows)
}

func (s *MockDataStore) ExpectContractNotFound() {
	s.mock.SQLMock.ExpectQuery(".* FROM \"contracts\"").WillReturnError(gorm.ErrRecordNotFound)
}

func (s *MockDataStore) ExpectContractError() {
	s.mock.SQLMock.ExpectQuery(".* FROM \"contracts\"").WillReturnError(gorm.ErrNotImplemented)
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

type ProcessorTestEnv struct {
	EventProcessor *EventProcessor
	Producers      *testProducerService
	FlagStore      *tests.MockFlagStore
	CacheStore     *tests.MockCacheStore
	DataStore      DataStore
	Cleanup        func()
}

func setupProcessorTestEnv(t *testing.T, useCache bool) *ProcessorTestEnv {
	var chargeCache models.Cacher
	var memCache *cache.Cache
	var apiStore *models.ApiStore
	var dataStore DataStore
	var cleanup func()

	testProducers := setupProducers()
	chargeCache = &tests.MockCacheStore{}
	flagStore := tests.MockFlagStore{}
	flagger := NewSubscriptionRefreshService(&flagStore)

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

	processor := NewEventProcessor(
		NewEventEnrichmentService(apiStore, memCache),
		testProducers.producerService,
		flagger,
	)

	return &ProcessorTestEnv{
		EventProcessor: processor,
		Producers:      testProducers,
		FlagStore:      &flagStore,
		CacheStore:     chargeCache.(*tests.MockCacheStore),
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
				StartedAt:      utils.NewNullTime(time.Unix(1700000000, 0)),
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

			result := testEnv.EventProcessor.processEvent(context.Background(), &event)

			assert.True(t, result.Success())
			assert.Equal(t, "12.0", *result.Value().Value)
			assert.Equal(t, "sum", result.Value().AggregationType)
			assert.Equal(t, "sub123", result.Value().SubscriptionID)

			time.Sleep(50 * time.Millisecond)
			assert.Equal(t, 1, testEnv.Producers.enrichedProducer.ExecutionCount)
			// The event was already post processed on API, no pay in advance production
			assert.Equal(t, 0, testEnv.Producers.inAdvanceProducer.ExecutionCount)
		})

		t.Run("When event source is not post process on API when timestamp is invalid", func(t *testing.T) {
			testEnv := setupProcessorTestEnv(t, mode.useCache)
			defer testEnv.Cleanup()

			event := models.Event{
				OrganizationID:         "1a901a90-1a90-1a90-1a90-1a901a901a90",
				ExternalSubscriptionID: "sub_id",
				Code:                   "api_calls",
				Timestamp:              "2025-03-06 12:00:00",
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
			assert.Equal(t, "strconv.ParseFloat: parsing \"2025-03-06 12:00:00\": invalid syntax", result.ErrorMsg())
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
				StartedAt:      utils.NewNullTime(time.Unix(1700000000, 0)),
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
				StartedAt:      utils.NewNullTime(time.Unix(1700000000, 0)),
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

			result := testEnv.EventProcessor.processEvent(context.Background(), &event)
			assert.True(t, result.Success())
			assert.Equal(t, "12", *result.Value().Value)

			// Give some time to the go routine to complete
			// TODO: Improve this by using channels in the producers methods
			time.Sleep(50 * time.Millisecond)
			assert.Equal(t, 1, testEnv.Producers.inAdvanceProducer.ExecutionCount)
			assert.Equal(t, 1, testEnv.Producers.enrichedProducer.ExecutionCount)

			assert.Equal(t, 1, testEnv.FlagStore.ExecutionCount)
		})

		t.Run("When event source is not post processed on API and no charge is charged in advance", func(t *testing.T) {
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
				StartedAt:      utils.NewNullTime(time.Unix(1700000000, 0)),
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
			assert.Equal(t, 0, testEnv.Producers.inAdvanceProducer.ExecutionCount)
		})

	}
}

func TestProcessCatalogEvent(t *testing.T) {
	testModes := []struct {
		name     string
		useCache bool
	}{
		{"WithCache", true},
		{"WithoutCache", false},
	}

	orgID := "1a901a90-1a90-1a90-1a90-1a901a901a90"

	buildEvent := func() models.Event {
		return models.Event{
			OrganizationID:     orgID,
			ExternalContractID: "contract_ext_id",
			TransactionID:      "tx_1",
			Code:               "api_calls",
			Timestamp:          1741007009,
			Source:             "SQS",
			Properties:         map[string]any{"api_requests": "12.0"},
		}
	}

	bm := &models.BillableMetric{
		ID:              "bm123",
		OrganizationID:  orgID,
		Code:            "api_calls",
		AggregationType: models.AggregationTypeSum,
		FieldName:       "api_requests",
		CreatedAt:       utils.NowNullTime(),
		UpdatedAt:       utils.NowNullTime(),
	}

	contract := &models.Contract{
		ID:             "contract123",
		OrganizationID: &orgID,
		ExternalID:     "contract_ext_id",
		Status:         models.ContractStatusActive,
		StartedAt:      utils.NewNullTime(time.Unix(1700000000, 0)),
	}

	for _, mode := range testModes {
		t.Run(mode.name, func(t *testing.T) {
			t.Run("without a contract, only writes the enriched event", func(t *testing.T) {
				testEnv := setupProcessorTestEnv(t, mode.useCache)
				defer testEnv.Cleanup()

				event := buildEvent()
				testEnv.DataStore.SetBillableMetric(bm)
				testEnv.DataStore.ExpectContractNotFound()

				result := testEnv.EventProcessor.processCatalogEvent(context.Background(), &event)

				require.True(t, result.Success())
				assert.Nil(t, result.Value().Contract)
				assert.Equal(t, 1, testEnv.Producers.catalogEnrichedProducer.ExecutionCount)
				assert.Equal(t, 0, testEnv.Producers.enrichedProducer.ExecutionCount)
				assert.Equal(t, 0, testEnv.Producers.inAdvanceProducer.ExecutionCount)
				assert.Equal(t, 0, testEnv.FlagStore.ExecutionCount)
			})

			t.Run("with an advance rate card, sends the event to price in advance", func(t *testing.T) {
				testEnv := setupProcessorTestEnv(t, mode.useCache)
				defer testEnv.Cleanup()

				event := buildEvent()
				testEnv.DataStore.SetBillableMetric(bm)
				testEnv.DataStore.SetContract(contract)
				testEnv.DataStore.SetAdvanceRateCard(orgID, contract.ID, bm.ID, true)

				result := testEnv.EventProcessor.processCatalogEvent(context.Background(), &event)

				require.True(t, result.Success())
				assert.Equal(t, "contract123", result.Value().Contract.ID)
				assert.Equal(t, 1, testEnv.Producers.catalogEnrichedProducer.ExecutionCount)
				assert.Equal(t, 1, testEnv.Producers.inAdvanceProducer.ExecutionCount)

				// The API job finds the contract through external_subscription_id.
				var payload map[string]any
				require.NoError(t, json.Unmarshal(testEnv.Producers.inAdvanceProducer.Value, &payload))
				assert.Equal(t, "contract_ext_id", payload["external_subscription_id"])
				assert.Equal(t, "tx_1", payload["transaction_id"])
				assert.Equal(t, "12.0", payload["value"])
			})

			t.Run("with an arrears rate card, sends nothing to price", func(t *testing.T) {
				testEnv := setupProcessorTestEnv(t, mode.useCache)
				defer testEnv.Cleanup()

				event := buildEvent()
				testEnv.DataStore.SetBillableMetric(bm)
				testEnv.DataStore.SetContract(contract)
				testEnv.DataStore.SetAdvanceRateCard(orgID, contract.ID, bm.ID, false)

				result := testEnv.EventProcessor.processCatalogEvent(context.Background(), &event)

				require.True(t, result.Success())
				assert.Equal(t, 1, testEnv.Producers.catalogEnrichedProducer.ExecutionCount)
				assert.Equal(t, 0, testEnv.Producers.inAdvanceProducer.ExecutionCount)
			})

			t.Run("when the API already post-processed the event, sends nothing to price", func(t *testing.T) {
				testEnv := setupProcessorTestEnv(t, mode.useCache)
				defer testEnv.Cleanup()

				event := buildEvent()
				event.Source = models.HTTP_RUBY
				event.SourceMetadata = &models.SourceMetadata{ApiPostProcess: true}
				testEnv.DataStore.SetBillableMetric(bm)
				testEnv.DataStore.SetContract(contract)

				result := testEnv.EventProcessor.processCatalogEvent(context.Background(), &event)

				require.True(t, result.Success())
				assert.Equal(t, 1, testEnv.Producers.catalogEnrichedProducer.ExecutionCount)
				assert.Equal(t, 0, testEnv.Producers.inAdvanceProducer.ExecutionCount)
			})

			t.Run("does not produce anything when enrichment fails", func(t *testing.T) {
				testEnv := setupProcessorTestEnv(t, mode.useCache)
				defer testEnv.Cleanup()

				testEnv.DataStore.ExpectBillableMetricNotFound()

				event := buildEvent()
				result := testEnv.EventProcessor.processCatalogEvent(context.Background(), &event)

				assert.False(t, result.Success())
				assert.Equal(t, "fetch_billable_metric", result.ErrorCode())
				assert.Equal(t, 0, testEnv.Producers.catalogEnrichedProducer.ExecutionCount)
			})
		})
	}

	t.Run("fails and retries when the advance lookup errors", func(t *testing.T) {
		testEnv := setupProcessorTestEnv(t, false)
		defer testEnv.Cleanup()

		event := buildEvent()
		testEnv.DataStore.SetBillableMetric(bm)
		testEnv.DataStore.SetContract(contract)
		testEnv.DataStore.(*MockDataStore).mock.SQLMock.
			ExpectQuery(".* FROM \"contract_rate_cards\".*").
			WillReturnError(gorm.ErrNotImplemented)

		result := testEnv.EventProcessor.processCatalogEvent(context.Background(), &event)

		assert.False(t, result.Success())
		assert.Equal(t, "fetch_advance_rate_card", result.ErrorCode())
		assert.True(t, result.IsRetryable())
		assert.Equal(t, 0, testEnv.Producers.inAdvanceProducer.ExecutionCount)
	})
}

func eventRecord(t *testing.T, offset int64, event models.Event) *kgo.Record {
	data, err := json.Marshal(event)
	require.NoError(t, err)

	return &kgo.Record{Value: data, Offset: offset}
}

func setupRecordTestEnv(t *testing.T) (*ProcessorTestEnv, *models.BillableMetric) {
	testEnv := setupProcessorTestEnv(t, true)

	bm := &models.BillableMetric{
		ID:              "bm123",
		OrganizationID:  "1a901a90-1a90-1a90-1a90-1a901a901a90",
		Code:            "api_calls",
		AggregationType: models.AggregationTypeSum,
		FieldName:       "api_requests",
		CreatedAt:       utils.NowNullTime(),
		UpdatedAt:       utils.NowNullTime(),
	}
	testEnv.DataStore.SetBillableMetric(bm)

	return testEnv, bm
}

func TestProcessCatalogEvents(t *testing.T) {
	testEnv, bm := setupRecordTestEnv(t)
	defer testEnv.Cleanup()

	valid := models.Event{
		IngestedAt:         utils.CustomTime(time.Now().UTC()),
		OrganizationID:     bm.OrganizationID,
		ExternalContractID: "contract_ext_id",
		TransactionID:      "tx_1",
		Code:               bm.Code,
		Timestamp:          1741007009,
		Source:             "SQS",
		Properties:         map[string]any{"api_requests": "12.0"},
	}
	withoutContract := valid
	withoutContract.ExternalContractID = ""
	withoutContract.TransactionID = "tx_2"

	records := []*kgo.Record{
		eventRecord(t, 1, valid),
		eventRecord(t, 2, withoutContract),
		{Value: []byte("not json"), Offset: 3},
	}

	processed := testEnv.EventProcessor.ProcessCatalogEvents(context.Background(), records)

	// Every record is committed: the valid one is enriched, the one without a
	// contract id goes to the dead letter queue although it was just ingested
	// (it is not retried), and unparsable JSON is skipped.
	assert.Len(t, processed, 3)
	assert.Equal(t, 1, testEnv.Producers.catalogEnrichedProducer.ExecutionCount)
	assert.Equal(t, 1, testEnv.Producers.deadLetterProducer.ExecutionCount)
	assert.Equal(t, 0, testEnv.Producers.enrichedProducer.ExecutionCount)
}

func TestProcessEvents(t *testing.T) {
	testEnv, bm := setupRecordTestEnv(t)
	defer testEnv.Cleanup()

	event := models.Event{
		OrganizationID:         bm.OrganizationID,
		ExternalSubscriptionID: "sub_id",
		TransactionID:          "tx_1",
		Code:                   bm.Code,
		Timestamp:              1741007009,
		Source:                 "SQS",
		Properties:             map[string]any{"api_requests": "12.0"},
	}

	records := []*kgo.Record{
		eventRecord(t, 1, event),
		{Value: []byte("not json"), Offset: 2},
	}

	processed := testEnv.EventProcessor.ProcessEvents(context.Background(), records)

	assert.Len(t, processed, 2)
	assert.Equal(t, 1, testEnv.Producers.enrichedProducer.ExecutionCount)
	assert.Equal(t, 0, testEnv.Producers.catalogEnrichedProducer.ExecutionCount)
	assert.Equal(t, 0, testEnv.Producers.deadLetterProducer.ExecutionCount)
}
