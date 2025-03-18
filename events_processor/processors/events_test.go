package processors

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"os"
	"testing"
	"time"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/stretchr/testify/assert"
	"gorm.io/gorm"

	"github.com/getlago/lago/events-processors/models"
	"github.com/getlago/lago/events-processors/utils"

	"github.com/getlago/lago/events-processors/tests"
)

func setupTestEnv(t *testing.T) (sqlmock.Sqlmock, func()) {
	ctx = context.Background()

	logger = slog.New(slog.NewJSONHandler(os.Stdout, nil))
	slog.SetDefault(logger)

	db, mock, delete := tests.SetupMockStore(t)
	apiStore = models.NewApiStore(db)

	return mock, delete
}

func mockBmLookup(sqlmock sqlmock.Sqlmock, bm *models.BillableMetric) {
	columns := []string{"id", "organization_id", "code", "field_name", "expression", "created_at", "updated_at", "deleted_at"}

	rows := sqlmock.NewRows(columns).
		AddRow(bm.ID, bm.OrganizationID, bm.Code, bm.FieldName, bm.Expression, bm.CreatedAt, bm.UpdatedAt, bm.DeletedAt)

	sqlmock.ExpectQuery("SELECT \\* FROM \"billable_metrics\".*").WillReturnRows(rows)
}

func mockSubscriptionLookup(sqlmock sqlmock.Sqlmock, sub *models.Subscription) {
	columns := []string{"id", "external_id", "plan_id", "created_at", "updated_at", "terminated_at"}

	rows := sqlmock.NewRows(columns).
		AddRow(sub.ID, sub.ExternalID, sub.PlanID, sub.CreatedAt, sub.UpdatedAt, sub.TerminatedAt)

	sqlmock.ExpectQuery(".* FROM \"subscriptions\".*").WillReturnRows(rows)
}

func mockChargeCount(sqlmock sqlmock.Sqlmock, chargeCount int) {
	row := sqlmock.NewRows([]string{"count"}).AddRow(chargeCount)
	sqlmock.ExpectQuery(".* FROM \"charges\"").WillReturnRows(row)
}

func TestProcessEvent(t *testing.T) {
	t.Run("Without Billable Metric", func(t *testing.T) {
		sqlmock, delete := setupTestEnv(t)
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

	t.Run("When event source is HTTP_RUBY", func(t *testing.T) {
		sqlmock, delete := setupTestEnv(t)
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
		}

		bm := models.BillableMetric{
			ID:             "bm123",
			OrganizationID: event.OrganizationID,
			Code:           event.Code,
			FieldName:      "api_requests",
			Expression:     "",
			CreatedAt:      time.Now(),
			UpdatedAt:      time.Now(),
		}
		mockBmLookup(sqlmock, &bm)

		enrichedProducer := tests.MockMessageProducer{}
		eventsEnrichedProducer = &enrichedProducer

		sub := models.Subscription{ID: "sub123"}
		mockSubscriptionLookup(sqlmock, &sub)

		result := processEvent(&event)

		assert.True(t, result.Success())
		assert.Equal(t, "12.0", *result.Value().Value)
		assert.Equal(t, "sub123", result.Value().SubscriptionID)

		// Give some time to the go routine to complete
		// TODO: Improve this by using channels in the producers methods
		time.Sleep(50 * time.Millisecond)
		assert.Equal(t, 1, enrichedProducer.ExecutionCount)
	})

	t.Run("When event source is not HTTP_RUBY when timestamp is invalid", func(t *testing.T) {
		sqlmock, delete := setupTestEnv(t)
		defer delete()

		event := models.Event{
			OrganizationID:         "1a901a90-1a90-1a90-1a90-1a901a901a90",
			ExternalSubscriptionID: "sub_id",
			Code:                   "api_calls",
			Timestamp:              "2025-03-06T12:00:00Z",
			Source:                 "SQS",
		}

		bm := models.BillableMetric{
			ID:             "bm123",
			OrganizationID: event.OrganizationID,
			Code:           event.Code,
			FieldName:      "api_requests",
			Expression:     "",
			CreatedAt:      time.Now(),
			UpdatedAt:      time.Now(),
		}
		mockBmLookup(sqlmock, &bm)

		result := processEvent(&event)
		assert.False(t, result.Success())
		assert.Equal(t, "strconv.ParseFloat: parsing \"2025-03-06T12:00:00Z\": invalid syntax", result.ErrorMsg())
		assert.Equal(t, "build_enriched_event", result.ErrorCode())
		assert.Equal(t, "Error while converting event to enriched event", result.ErrorMessage())
	})

	t.Run("When event source is not HTTP_RUBY when no subscriptions are found", func(t *testing.T) {
		sqlmock, delete := setupTestEnv(t)
		defer delete()

		event := models.Event{
			OrganizationID:         "1a901a90-1a90-1a90-1a90-1a901a901a90",
			ExternalSubscriptionID: "sub_id",
			Code:                   "api_calls",
			Timestamp:              1741007009,
			Source:                 "SQS",
		}

		bm := models.BillableMetric{
			ID:             "bm123",
			OrganizationID: event.OrganizationID,
			Code:           event.Code,
			FieldName:      "api_requests",
			Expression:     "",
			CreatedAt:      time.Now(),
			UpdatedAt:      time.Now(),
		}
		mockBmLookup(sqlmock, &bm)

		sqlmock.ExpectQuery(".* FROM \"subscriptions\"").WillReturnError(gorm.ErrRecordNotFound)

		result := processEvent(&event)
		assert.False(t, result.Success())
		assert.Equal(t, "record not found", result.ErrorMsg())
		assert.Equal(t, "fetch_subscription", result.ErrorCode())
		assert.Equal(t, "Error fetching subscription", result.ErrorMessage())
	})

	t.Run("When event source is not HTTP_RUBY when expression failed to evaluate", func(t *testing.T) {
		sqlmock, delete := setupTestEnv(t)
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
			ID:             "bm123",
			OrganizationID: event.OrganizationID,
			Code:           event.Code,
			FieldName:      "api_requests",
			Expression:     "round(event.properties.value)",
			CreatedAt:      time.Now(),
			UpdatedAt:      time.Now(),
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

	t.Run("When event source is not HTTP_RUBY and events belongs to an in advance charge", func(t *testing.T) {
		sqlmock, delete := setupTestEnv(t)
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
			ID:             "bm123",
			OrganizationID: event.OrganizationID,
			Code:           event.Code,
			FieldName:      "api_requests",
			Expression:     "round(event.properties.value)",
			CreatedAt:      time.Now(),
			UpdatedAt:      time.Now(),
		}
		mockBmLookup(sqlmock, &bm)

		sub := models.Subscription{ID: "sub123"}
		mockSubscriptionLookup(sqlmock, &sub)

		mockChargeCount(sqlmock, 3)

		inAdvanceProducer := tests.MockMessageProducer{}
		eventsInAdvanceProducer = &inAdvanceProducer
		enrichedProducer := tests.MockMessageProducer{}
		eventsEnrichedProducer = &enrichedProducer

		result := processEvent(&event)
		assert.True(t, result.Success())
		assert.Equal(t, "12", *result.Value().Value)

		// Give some time to the go routine to complete
		// TODO: Improve this by using channels in the producers methods
		time.Sleep(50 * time.Millisecond)
		assert.Equal(t, 1, inAdvanceProducer.ExecutionCount)
		assert.Equal(t, 1, enrichedProducer.ExecutionCount)
	})
}

func TestEvaluateExpression(t *testing.T) {
	bm := models.BillableMetric{}
	event := models.EnrichedEvent{Timestamp: 1741007009.0, Code: "foo"}
	var result utils.Result[bool]

	t.Run("Without expression", func(t *testing.T) {
		result = evaluateExpression(&event, &bm)
		assert.True(t, result.Success(), "It should succeed when Billable metric does not have a custom expression")
	})

	t.Run("With an expression but witout required fields", func(t *testing.T) {
		bm.Expression = "round(event.properties.value * event.properties.units)"
		bm.FieldName = "total_value"
		result = evaluateExpression(&event, &bm)
		assert.False(t, result.Success())
		assert.Contains(
			t,
			result.ErrorMsg(),
			"Failed to evaluate expr:",
			"It should fail when the event does not hold the required fields",
		)
	})

	t.Run("With an expression and with required fields", func(t *testing.T) {
		properties := map[string]any{
			"value": "12.0",
			"units": 3,
		}
		event.Properties = properties
		result = evaluateExpression(&event, &bm)
		assert.True(t, result.Success())
		assert.Equal(t, "36", event.Properties["total_value"])
	})

	t.Run("With a float timestamp", func(t *testing.T) {
		event.Timestamp = 1741007009.123

		result = evaluateExpression(&event, &bm)
		assert.True(t, result.Success())
		assert.Equal(t, "36", event.Properties["total_value"])
	})
}

func TestProduceEnrichedEvent(t *testing.T) {
	producer := tests.MockMessageProducer{}
	eventsEnrichedProducer = &producer
	ctx = context.Background()

	event := models.EnrichedEvent{
		OrganizationID:         "1a901a90-1a90-1a90-1a90-1a901a901a90",
		ExternalSubscriptionID: "sub_id",
		Code:                   "api_calls",
	}

	produceEnrichedEvent(&event)

	assert.Equal(t, 1, producer.ExecutionCount)
	assert.Equal(
		t,
		[]byte("1a901a90-1a90-1a90-1a90-1a901a901a90-sub_id-api_calls"),
		producer.Key,
	)

	eventJson, _ := json.Marshal(event)
	assert.Equal(t, eventJson, producer.Value)
}

func TestProduceChargedInAdvanceEvent(t *testing.T) {
	producer := tests.MockMessageProducer{}
	eventsInAdvanceProducer = &producer
	ctx = context.Background()

	event := models.EnrichedEvent{
		OrganizationID:         "1a901a90-1a90-1a90-1a90-1a901a901a90",
		ExternalSubscriptionID: "sub_id",
		Code:                   "api_calls",
	}

	produceChargedInAdvanceEvent(&event)

	assert.Equal(t, 1, producer.ExecutionCount)
	assert.Equal(
		t,
		[]byte("1a901a90-1a90-1a90-1a90-1a901a901a90-sub_id-api_calls"),
		producer.Key,
	)

	eventJson, _ := json.Marshal(event)
	assert.Equal(t, eventJson, producer.Value)
}

func TestProduceToDeadLetterQueue(t *testing.T) {
	producer := tests.MockMessageProducer{}
	eventsDeadLetterQueue = &producer
	ctx = context.Background()

	event := models.Event{
		OrganizationID:         "1a901a90-1a90-1a90-1a90-1a901a901a90",
		ExternalSubscriptionID: "sub_id",
		Code:                   "api_calls",
	}

	result := utils.FailedResult[string](fmt.Errorf("Error Message"))
	produceToDeadLetterQueue(event, result)

	var producedEvent models.FailedEvent
	err := json.Unmarshal(producer.Value, &producedEvent)

	assert.NoError(t, err)
	assert.Equal(t, 1, producer.ExecutionCount)

	assert.Equal(t, event, producedEvent.Event)
	assert.Equal(t, "Error Message", producedEvent.InitialErrorMessage)
	assert.Equal(t, "", producedEvent.ErrorCode)
	assert.Equal(t, "", producedEvent.ErrorMessage)
	assert.WithinDuration(t, time.Now(), producedEvent.FailedAt, 5*time.Second)
}

func TestProduceRefreshedSubscriptions(t *testing.T) {
	producer := tests.MockMessageProducer{}
	refreshedSubscriptionProducer = &producer
	ctx = context.Background()

	values := make(map[string]models.RefreshedSubscription)
	refreshedValues := models.RefreshedSubscriptions{Values: values}

	sub1 := models.RefreshedSubscription{
		ID:             "sub_123",
		OrganizationID: "org_123",
		RefreshedAt:    time.Now(),
	}
	refreshedValues.Values[sub1.ID] = sub1

	sub2 := models.RefreshedSubscription{
		ID:             "sub_456",
		OrganizationID: "org_456",
		RefreshedAt:    time.Now(),
	}
	refreshedValues.Values[sub2.ID] = sub2

	produceRefreshedSubscriptions(&refreshedValues)

	assert.Equal(t, 2, producer.ExecutionCount)
	assert.Equal(
		t,
		[]byte("org_456-sub_456"),
		producer.Key,
	)
	refreshedJson, _ := json.Marshal(sub2)
	assert.Equal(t, refreshedJson, producer.Value)
}
