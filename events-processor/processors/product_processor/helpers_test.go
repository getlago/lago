package product_processor

import (
	"context"
	"encoding/json"
	"errors"
	"testing"
	"time"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/stretchr/testify/require"
	"github.com/twmb/franz-go/pkg/kgo"
	"gorm.io/gorm"

	"github.com/getlago/lago/events-processor/cache"
	"github.com/getlago/lago/events-processor/config/kafka"
	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/tests"
	"github.com/getlago/lago/events-processor/utils"
)

const orgID = "1a901a90-1a90-1a90-1a90-1a901a901a90"

var testModes = []struct {
	name     string
	useCache bool
}{
	{"WithCache", true},
	{"WithoutCache", false},
}

func buildEvent() models.ProductEvent {
	return models.ProductEvent{
		IngestedAt:         utils.CustomTime(time.Now().UTC()),
		OrganizationID:     orgID,
		ExternalContractID: "contract_ext_id",
		TransactionID:      "tx_1",
		Code:               "api_calls",
		Timestamp:          1741007009,
		Source:             "SQS",
		Properties:         map[string]any{"api_requests": "12.0"},
	}
}

func buildBillableMetric() *models.BillableMetric {
	return &models.BillableMetric{
		ID:              "bm123",
		OrganizationID:  orgID,
		Code:            "api_calls",
		AggregationType: models.AggregationTypeSum,
		FieldName:       "api_requests",
		CreatedAt:       utils.NowNullTime(),
		UpdatedAt:       utils.NowNullTime(),
	}
}

func eventRecord(t *testing.T, offset int64, event models.ProductEvent) *kgo.Record {
	data, err := json.Marshal(event)
	require.NoError(t, err)

	return &kgo.Record{Value: data, Offset: offset}
}

// DataStore abstracts cache vs DB mock setup
type DataStore interface {
	SetBillableMetric(bm *models.BillableMetric)
	ExpectBillableMetricNotFound()
	ExpectAdvanceRateCard(found bool)
	ExpectAdvanceRateCardError()
}

// advanceRateCards mocks the advance rate card lookup, which reads PostgreSQL with or
// without the memory cache.
type advanceRateCards struct {
	mock *tests.MockedStore
}

func (s advanceRateCards) ExpectAdvanceRateCard(found bool) {
	rows := sqlmock.NewRows([]string{"id"})
	if found {
		rows.AddRow("crc123")
	}
	s.mock.SQLMock.ExpectQuery(".* FROM contract_rate_cards.*").WillReturnRows(rows)
}

func (s advanceRateCards) ExpectAdvanceRateCardError() {
	s.mock.SQLMock.ExpectQuery(".* FROM contract_rate_cards.*").WillReturnError(errors.New("connection refused"))
}

type CacheDataStore struct {
	advanceRateCards
	cache *cache.Cache
	t     *testing.T
}

func (s *CacheDataStore) SetBillableMetric(bm *models.BillableMetric) {
	require.True(s.t, s.cache.SetBillableMetric(bm).Success())
}

func (s *CacheDataStore) ExpectBillableMetricNotFound() {}

type MockDataStore struct {
	advanceRateCards
	mock *tests.MockedStore
	t    *testing.T
}

func (s *MockDataStore) SetBillableMetric(bm *models.BillableMetric) {
	columns := []string{"id", "organization_id", "code", "aggregation_type", "recurring", "field_name", "expression", "created_at", "updated_at", "deleted_at", "has_usage_attribution_types"}
	rows := sqlmock.NewRows(columns).
		AddRow(bm.ID, bm.OrganizationID, bm.Code, bm.AggregationType, bm.Recurring, bm.FieldName, bm.Expression, bm.CreatedAt, bm.UpdatedAt, bm.DeletedAt, bm.HasUsageAttributionTypes)
	s.mock.SQLMock.ExpectQuery(".* FROM \"billable_metrics\".*").WillReturnRows(rows)
}

func (s *MockDataStore) ExpectBillableMetricNotFound() {
	s.mock.SQLMock.ExpectQuery(".*").WillReturnError(gorm.ErrRecordNotFound)
}

type testProducers struct {
	enriched   *tests.MockMessageProducer
	inAdvance  *tests.MockMessageProducer
	deadLetter *tests.MockMessageProducer
}

type testEnv struct {
	Processor *ProductProcessor
	Producers testProducers
	DataStore DataStore
	Cleanup   func()
}

func setupTestEnv(t *testing.T, useCache bool) *testEnv {
	return newTestEnv(t, useCache, false)
}

// setupTestEnvChargingInAdvance runs the pipeline with the in advance topic configured.
func setupTestEnvChargingInAdvance(t *testing.T, useCache bool) *testEnv {
	return newTestEnv(t, useCache, true)
}

func newTestEnv(t *testing.T, useCache bool, chargesInAdvance bool) *testEnv {
	var memCache *cache.Cache
	var dataStore DataStore

	mockedStore, deleteFunc := tests.SetupMockStore(t)
	cleanup := deleteFunc

	// As in production, the cache mode opens no database unless it charges in advance.
	var apiStore *models.ApiStore
	if !useCache || chargesInAdvance {
		apiStore = models.NewApiStore(mockedStore.DB)
	}

	if useCache {
		memCache, _ = cache.NewCache(cache.CacheConfig{
			Context:  context.Background(),
			Pipeline: cache.PipelineProductEvents,
		})
		dataStore = &CacheDataStore{advanceRateCards: advanceRateCards{mock: mockedStore}, cache: memCache, t: t}
		cleanup = func() {
			memCache.Close()
			deleteFunc()
		}
	} else {
		dataStore = &MockDataStore{advanceRateCards: advanceRateCards{mock: mockedStore}, mock: mockedStore, t: t}
	}

	producers := testProducers{
		enriched:   &tests.MockMessageProducer{},
		inAdvance:  &tests.MockMessageProducer{},
		deadLetter: &tests.MockMessageProducer{},
	}

	var inAdvanceProducer kafka.MessageProducer
	if chargesInAdvance {
		inAdvanceProducer = producers.inAdvance
	}

	return &testEnv{
		Processor: NewProductProcessor(
			NewEnrichmentService(apiStore, memCache),
			NewProducerService(producers.enriched, inAdvanceProducer, producers.deadLetter),
		),
		Producers: producers,
		DataStore: dataStore,
		Cleanup:   cleanup,
	}
}
