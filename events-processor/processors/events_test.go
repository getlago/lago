package processors

import (
	"context"
	"log/slog"
	"os"
	"testing"
	"time"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/stretchr/testify/assert"
	"gorm.io/gorm"

	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/processors/event_processors"
	"github.com/getlago/lago/events-processor/utils"

	"github.com/getlago/lago/events-processor/tests"
)

type testProducerService struct {
	enrichedProducer         *tests.MockMessageProducer
	enrichedExpandedProducer *tests.MockMessageProducer
	inAdvanceProducer        *tests.MockMessageProducer
	deadLetterProducer       *tests.MockMessageProducer
	producers                *event_processors.EventProducerService
}

func setupProducers() *testProducerService {
	enrichedProducer := tests.MockMessageProducer{}
	enrichedExpandedProducer := tests.MockMessageProducer{}
	inAdvanceProducer := tests.MockMessageProducer{}
	deadLetterProducer := tests.MockMessageProducer{}

	logger = slog.New(slog.NewJSONHandler(os.Stdout, nil))
	slog.SetDefault(logger)

	producers := event_processors.NewEventProducerService(
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

func setupTestEnv(t *testing.T) (sqlmock.Sqlmock, *testProducerService, *tests.MockFlagStore, func()) {
	ctx = context.Background()

	logger = slog.New(slog.NewJSONHandler(os.Stdout, nil))
	slog.SetDefault(logger)

	db, mock, delete := tests.SetupMockStore(t)
	apiStore = models.NewApiStore(db)

	testProducers := setupProducers()

	cacheStore := tests.MockCacheStore{}
	var chargeCache models.Cacher = &cacheStore
	chargeCacheStore := models.NewChargeCache(&chargeCache)

	flagStore := tests.MockFlagStore{}
	flagger := event_processors.NewSubscriptionRefreshService(&flagStore)

	processor = event_processors.NewEventProcessor(
		event_processors.NewEventEnrichmentService(apiStore),
		testProducers.producers,
		flagger,
		event_processors.NewCacheService(chargeCacheStore),
	)

	return mock, testProducers, &flagStore, delete
}

func mockBmLookup(sqlmock sqlmock.Sqlmock, bm *models.BillableMetric) {
	columns := []string{"id", "organization_id", "code", "aggregation_type", "field_name", "expression", "created_at", "updated_at", "deleted_at"}

	rows := sqlmock.NewRows(columns).
		AddRow(bm.ID, bm.OrganizationID, bm.Code, bm.AggregationType, bm.FieldName, bm.Expression, bm.CreatedAt, bm.UpdatedAt, bm.DeletedAt)

	sqlmock.ExpectQuery("SELECT \\* FROM \"billable_metrics\".*").WillReturnRows(rows)
}

func mockSubscriptionLookup(sqlmock sqlmock.Sqlmock, sub *models.Subscription) {
	columns := []string{"id", "external_id", "plan_id", "created_at", "updated_at", "terminated_at"}

	rows := sqlmock.NewRows(columns).
		AddRow(sub.ID, sub.ExternalID, sub.PlanID, sub.CreatedAt, sub.UpdatedAt, sub.TerminatedAt)

	sqlmock.ExpectQuery(".* FROM \"subscriptions\".*").WillReturnRows(rows)
}

func mockFlatFiltersLookup(sqlmock sqlmock.Sqlmock, filters []*models.FlatFilter) {
	columns := []string{"organization_id", "billable_metric_code", "plan_id", "charge_id", "charge_updated_at", "charge_filter_id", "charge_filter_updated_at", "filters", "pay_in_advance"}

	rows := sqlmock.NewRows(columns)

	for _, filter := range filters {
		rows.AddRow(filter.OrganizationID, filter.BillableMetricCode, filter.PlanID, filter.ChargeID, filter.ChargeUpdatedAt, filter.ChargeFilterID, filter.ChargeFilterUpdatedAt, filter.Filters, filter.PayInAdvance)
	}
	sqlmock.ExpectQuery(".* FROM \"flat_filters\".*").WillReturnRows(rows)
}

func TestProcessEvent(t *testing.T) {
	t.Run("Without Billable Metric", func(t *testing.T) {
		sqlmock, _, _, delete := setupTestEnv(t)
		defer delete()

		event := models.Event{
			OrganizationID:         "1a901a90-1a90-1a90-1a90-1a901a901a90",
			ExternalSubscriptionID: "sub_id",
			Code:                   "api_calls",
			Timestamp:              1741007009,
		}

		sqlmock.ExpectQuery(".*").WillReturnError(gorm.ErrRecordNotFound)

		result := processEvent(&event)
		assert.False(t, result.Success())
		assert.Equal(t, "record not found", result.ErrorMsg())
		assert.Equal(t, "fetch_billable_metric", result.ErrorCode())
		assert.Equal(t, "Error fetching billable metric", result.ErrorMessage())
	})

	t.Run("When event source is post processed on API", func(t *testing.T) {
		sqlmock, testProducers, _, delete := setupTestEnv(t)
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
			CreatedAt:       time.Now(),
			UpdatedAt:       time.Now(),
		}
		mockBmLookup(sqlmock, &bm)

		sub := models.Subscription{ID: "sub123", PlanID: "plan123"}
		mockSubscriptionLookup(sqlmock, &sub)

		result := processEvent(&event)

		assert.True(t, result.Success())
		assert.Equal(t, "12.0", *result.Value().Value)
		assert.Equal(t, "sum", result.Value().AggregationType)
		assert.Equal(t, "sub123", result.Value().SubscriptionID)
		assert.Equal(t, "plan123", result.Value().PlanID)

		// Give some time to the go routine to complete
		// TODO: Improve this by using channels in the producers methods
		time.Sleep(50 * time.Millisecond)
		assert.Equal(t, 1, testProducers.enrichedProducer.ExecutionCount)
		// TODO(pre-aggregation): assert.Equal(t, 1, testProducers.enrichedExpandedProducer.ExecutionCount)
	})

	t.Run("When event source is not post process on API when timestamp is invalid", func(t *testing.T) {
		sqlmock, _, _, delete := setupTestEnv(t)
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
			CreatedAt:       time.Now(),
			UpdatedAt:       time.Now(),
		}
		mockBmLookup(sqlmock, &bm)

		result := processEvent(&event)
		assert.False(t, result.Success())
		assert.Equal(t, "strconv.ParseFloat: parsing \"2025-03-06T12:00:00Z\": invalid syntax", result.ErrorMsg())
		assert.Equal(t, "build_enriched_event", result.ErrorCode())
		assert.Equal(t, "Error while converting event to enriched event", result.ErrorMessage())
	})

	t.Run("When event source is not post process on API when no subscriptions are found", func(t *testing.T) {
		sqlmock, _, _, delete := setupTestEnv(t)
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
			CreatedAt:       time.Now(),
			UpdatedAt:       time.Now(),
		}
		mockBmLookup(sqlmock, &bm)

		sqlmock.ExpectQuery(".* FROM \"subscriptions\"").WillReturnError(gorm.ErrRecordNotFound)

		result := processEvent(&event)
		assert.True(t, result.Success())
	})

	t.Run("When event source is not post process on API with error when fetching subscription", func(t *testing.T) {
		sqlmock, _, _, delete := setupTestEnv(t)
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
			CreatedAt:       time.Now(),
			UpdatedAt:       time.Now(),
		}
		mockBmLookup(sqlmock, &bm)

		sqlmock.ExpectQuery(".* FROM \"subscriptions\"").WillReturnError(gorm.ErrNotImplemented)

		result := processEvent(&event)
		assert.False(t, result.Success())
		assert.NotNil(t, result.ErrorMsg())
		assert.Equal(t, "fetch_subscription", result.ErrorCode())
		assert.Equal(t, "Error fetching subscription", result.ErrorMessage())
	})

	t.Run("When event source is not post process on API when expression failed to evaluate", func(t *testing.T) {
		sqlmock, _, _, delete := setupTestEnv(t)
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
			CreatedAt:       time.Now(),
			UpdatedAt:       time.Now(),
		}
		mockBmLookup(sqlmock, &bm)

		sub := models.Subscription{ID: "sub123"}
		mockSubscriptionLookup(sqlmock, &sub)

		result := processEvent(&event)
		assert.False(t, result.Success())
		assert.Contains(t, result.ErrorMsg(), "Failed to evaluate expr: round(event.properties.value)")
		assert.Equal(t, "evaluate_expression", result.ErrorCode())
		assert.Equal(t, "Error evaluating custom expression", result.ErrorMessage())
	})

	t.Run("When event source is not post process on API and events belongs to an in advance charge", func(t *testing.T) {
		sqlmock, testProducers, flagger, delete := setupTestEnv(t)
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
			CreatedAt:       time.Now(),
			UpdatedAt:       time.Now(),
		}
		mockBmLookup(sqlmock, &bm)

		sub := models.Subscription{ID: "sub123"}
		mockSubscriptionLookup(sqlmock, &sub)

		now := time.Now()

		mockFlatFiltersLookup(sqlmock, []*models.FlatFilter{
			{
				OrganizationID:     "org_id",
				BillableMetricCode: "api_call",
				PlanID:             "plan_id",
				ChargeID:           "charge_idxx",
				ChargeUpdatedAt:    now,
				PayInAdvance:       true,
			},
		})

		result := processEvent(&event)
		assert.True(t, result.Success())
		assert.Equal(t, "12", *result.Value().Value)

		// Give some time to the go routine to complete
		// TODO: Improve this by using channels in the producers methods
		time.Sleep(50 * time.Millisecond)
		assert.Equal(t, 1, testProducers.inAdvanceProducer.ExecutionCount)
		assert.Equal(t, 1, testProducers.enrichedProducer.ExecutionCount)
		// TODO(pre-aggregation): assert.Equal(t, 1, testProducers.enrichedExpandedProducer.ExecutionCount)

		assert.Equal(t, 1, flagger.ExecutionCount)
	})

	t.Run("When event source is not post processed on API and it matches multiple charges", func(t *testing.T) {
		sqlmock, testProducers, _, delete := setupTestEnv(t)
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
			CreatedAt:       time.Now(),
			UpdatedAt:       time.Now(),
		}
		mockBmLookup(sqlmock, &bm)

		sub := models.Subscription{ID: "sub123", PlanID: "plan123"}
		mockSubscriptionLookup(sqlmock, &sub)

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
		mockFlatFiltersLookup(sqlmock, []*models.FlatFilter{flatFilter1, flatFilter2})

		result := processEvent(&event)

		assert.True(t, result.Success())
		assert.Equal(t, "12.0", *result.Value().Value)
		assert.Equal(t, "sum", result.Value().AggregationType)
		assert.Equal(t, "sub123", result.Value().SubscriptionID)
		assert.Equal(t, "plan123", result.Value().PlanID)

		// Give some time to the go routine to complete
		// TODO: Improve this by using channels in the producers methods
		time.Sleep(50 * time.Millisecond)
		assert.Equal(t, 1, testProducers.enrichedProducer.ExecutionCount)
		// TODO(pre-aggregation): assert.Equal(t, 2, testProducers.enrichedExpandedProducer.ExecutionCount)
	})

	t.Run("When event source is not post processed on API and it matches no charges", func(t *testing.T) {
		sqlmock, testProducers, _, delete := setupTestEnv(t)
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
			CreatedAt:       time.Now(),
			UpdatedAt:       time.Now(),
		}
		mockBmLookup(sqlmock, &bm)

		sub := models.Subscription{ID: "sub123", PlanID: "plan123"}
		mockSubscriptionLookup(sqlmock, &sub)
		mockFlatFiltersLookup(sqlmock, []*models.FlatFilter{})

		result := processEvent(&event)

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
