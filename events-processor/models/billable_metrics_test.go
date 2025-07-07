package models

import (
	"errors"
	"regexp"
	"testing"
	"time"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/stretchr/testify/assert"
	"gorm.io/gorm"
)

var fetchBillableMetricQuery = regexp.QuoteMeta(`
	SELECT * FROM "billable_metrics"
	WHERE (organization_id = $1 AND code = $2)
	AND "billable_metrics"."deleted_at" IS NULL
	ORDER BY "billable_metrics"."id"
	LIMIT $3`,
)

func TestFetchBillableMetric(t *testing.T) {
	t.Run("should return billable metric when found", func(t *testing.T) {
		// Setup
		store, mock, cleanup := setupApiStore(t)
		defer cleanup()

		orgID := "1a901a90-1a90-1a90-1a90-1a901a901a90"
		code := "api_calls"
		now := time.Now()

		// Define expected rows and columns
		columns := []string{"id", "organization_id", "code", "aggregation_type", "field_name", "expression", "created_at", "updated_at", "deleted_at"}
		rows := sqlmock.NewRows(columns).
			AddRow("bm123", orgID, code, 0, "api_requests", "count", now, now, nil)

		// Expect the query
		mock.ExpectQuery(fetchBillableMetricQuery).
			WithArgs(orgID, code, 1).
			WillReturnRows(rows)

		// Execute
		result := store.FetchBillableMetric(orgID, code)

		// Assert
		assert.True(t, result.Success())

		metric := result.Value()
		assert.NotNil(t, metric)
		assert.Equal(t, "bm123", metric.ID)
		assert.Equal(t, orgID, metric.OrganizationID)
		assert.Equal(t, code, metric.Code)
		assert.Equal(t, AggregationType(0), metric.AggregationType)
		assert.Equal(t, "api_requests", metric.FieldName)
		assert.Equal(t, "count", metric.Expression)
	})

	t.Run("should return error when billable metric not found", func(t *testing.T) {
		// Setup
		store, mock, cleanup := setupApiStore(t)
		defer cleanup()

		orgID := "1a901a90-1a90-1a90-1a90-1a901a901a90"
		code := "api_calls"

		// Expect the query but return error
		mock.ExpectQuery(fetchBillableMetricQuery).
			WithArgs(orgID, code, 1).
			WillReturnError(gorm.ErrRecordNotFound)

		// Execute
		result := store.FetchBillableMetric(orgID, code)

		// Assert
		assert.False(t, result.Success())
		assert.NotNil(t, result.Error())
		assert.Equal(t, gorm.ErrRecordNotFound, result.Error())
		assert.Nil(t, result.Value())
		assert.False(t, result.IsCapturable())
		assert.False(t, result.IsRetryable())
	})

	t.Run("should handle database connection error", func(t *testing.T) {
		// Setup
		store, mock, cleanup := setupApiStore(t)
		defer cleanup()

		orgID := "1a901a90-1a90-1a90-1a90-1a901a901a90"
		code := "api_calls"
		dbError := errors.New("database connection failed")

		// Expect the query but return error
		mock.ExpectQuery(fetchBillableMetricQuery).
			WithArgs(orgID, code, 1).
			WillReturnError(dbError)

		// Execute
		result := store.FetchBillableMetric(orgID, code)

		// Assert
		assert.False(t, result.Success())
		assert.NotNil(t, result.Error())
		assert.Equal(t, dbError, result.Error())
		assert.Nil(t, result.Value())
		assert.True(t, result.IsCapturable())
		assert.True(t, result.IsRetryable())
	})
}

func TestAggregationTypeString(t *testing.T) {
	t.Run("should return the aggregation type", func(t *testing.T) {
		tests := []struct {
			aggregationType int
			expected        string
		}{
			{0, "count"},
			{1, "sum"},
			{2, "max"},
			{3, "unique_count"},
			{5, "weighted_sum"},
			{6, "latest"},
			{7, "custom"},
		}

		for _, test := range tests {
			var bm = BillableMetric{AggregationType: AggregationType(test.aggregationType)}
			assert.Equal(t, test.expected, bm.AggregationType.String())
		}
	})

	t.Run("should return an empty string for invalid aggregation type", func(t *testing.T) {
		var bm = BillableMetric{AggregationType: 99}
		assert.Equal(t, "", bm.AggregationType.String())
	})
}
