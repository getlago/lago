package catalog_processor

import (
	"context"
	"encoding/json"
	"testing"
	"time"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/stretchr/testify/require"
	"github.com/twmb/franz-go/pkg/kgo"
	"gorm.io/gorm"

	"github.com/getlago/lago/events-processor/cache"
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

func buildEvent() models.Event {
	return models.Event{
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

func buildContract(startedAt time.Time) *models.Contract {
	organizationID := orgID
	return &models.Contract{
		ID:             "contract123",
		OrganizationID: &organizationID,
		ExternalID:     "contract_ext_id",
		Status:         models.ContractStatusActive,
		StartedAt:      utils.NewNullTime(startedAt),
	}
}

func eventRecord(t *testing.T, offset int64, event models.Event) *kgo.Record {
	data, err := json.Marshal(event)
	require.NoError(t, err)

	return &kgo.Record{Value: data, Offset: offset}
}

// DataStore abstracts cache vs DB mock setup
type DataStore interface {
	SetBillableMetric(bm *models.BillableMetric)
	SetContract(contract *models.Contract)
	SetAdvanceRateCard(organizationID, contractID, billableMetricID string, advance bool)
	ExpectContractNotFound()
	ExpectContractError()
	ExpectBillableMetricNotFound()
}

type CacheDataStore struct {
	cache *cache.Cache
	t     *testing.T
}

func (s *CacheDataStore) SetBillableMetric(bm *models.BillableMetric) {
	require.True(s.t, s.cache.SetBillableMetric(bm).Success())
}

func (s *CacheDataStore) SetContract(contract *models.Contract) {
	require.True(s.t, s.cache.SetContract(contract).Success())
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
func (s *CacheDataStore) ExpectBillableMetricNotFound() {}

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

func (s *MockDataStore) ExpectBillableMetricNotFound() {
	s.mock.SQLMock.ExpectQuery(".*").WillReturnError(gorm.ErrRecordNotFound)
}

type testProducers struct {
	enriched   *tests.MockMessageProducer
	inAdvance  *tests.MockMessageProducer
	deadLetter *tests.MockMessageProducer
}

type testEnv struct {
	Processor *CatalogProcessor
	Producers testProducers
	DataStore DataStore
	Cleanup   func()
}

func setupTestEnv(t *testing.T, useCache bool) *testEnv {
	var memCache *cache.Cache
	var apiStore *models.ApiStore
	var dataStore DataStore
	var cleanup func()

	if useCache {
		memCache, _ = cache.NewCache(cache.CacheConfig{
			Context:  context.Background(),
			Pipeline: cache.PipelineCatalogEvents,
		})
		dataStore = &CacheDataStore{cache: memCache, t: t}
		cleanup = func() { memCache.Close() }
	} else {
		mockedStore, deleteFunc := tests.SetupMockStore(t)
		apiStore = models.NewApiStore(mockedStore.DB)
		dataStore = &MockDataStore{mock: mockedStore, t: t}
		cleanup = deleteFunc
	}

	producers := testProducers{
		enriched:   &tests.MockMessageProducer{},
		inAdvance:  &tests.MockMessageProducer{},
		deadLetter: &tests.MockMessageProducer{},
	}

	return &testEnv{
		Processor: NewCatalogProcessor(
			NewEnrichmentService(apiStore, memCache),
			NewProducerService(producers.enriched, producers.inAdvance, producers.deadLetter),
		),
		Producers: producers,
		DataStore: dataStore,
		Cleanup:   cleanup,
	}
}
