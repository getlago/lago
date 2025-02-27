package database

import (
	"errors"
	"testing"
	"time"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/stretchr/testify/assert"
	"gorm.io/gorm"
)

var fetchBillableMetricQuery = `^SELECT \* FROM "billable_metrics" WHERE \(organization_id = \$1 AND code = \$2\) AND "billable_metrics"."deleted_at" IS NULL ORDER BY "billable_metrics"."id" LIMIT \$3$`

func TestFetchBillableMetric(t *testing.T) {
	t.Run("should return billable metric when found", func(t *testing.T) {
		// Setup
		db, mock, cleanup := setupMockDB(t)
		defer cleanup()

		orgID := "1a901a90-1a90-1a90-1a90-1a901a901a90"
		code := "api_calls"
		now := time.Now()

		// Define expected rows and columns
		columns := []string{"id", "organization_id", "code", "field_name", "expression", "created_at", "updated_at", "deleted_at"}
		rows := sqlmock.NewRows(columns).
			AddRow("bm123", orgID, code, "api_requests", "count", now, now, nil)

		// Expect the query
		mock.ExpectQuery(fetchBillableMetricQuery).
			WithArgs(orgID, code, 1).
			WillReturnRows(rows)

		// Execute
		result := db.FetchBillableMetric(orgID, code)

		// Assert
		assert.True(t, result.Success())

		metric := result.Value()
		assert.NotNil(t, metric)
		assert.Equal(t, "bm123", metric.ID)
		assert.Equal(t, orgID, metric.OrganizationID)
		assert.Equal(t, code, metric.Code)
		assert.Equal(t, "api_requests", metric.FieldName)
		assert.Equal(t, "count", metric.Expression)
	})

	t.Run("should return error when billable metric not found", func(t *testing.T) {
		// Setup
		db, mock, cleanup := setupMockDB(t)
		defer cleanup()

		orgID := "org123"
		code := "api_calls"

		// Expect the query but return error
		mock.ExpectQuery(fetchBillableMetricQuery).
			WithArgs(orgID, code, 1).
			WillReturnError(gorm.ErrRecordNotFound)

		// Execute
		result := db.FetchBillableMetric(orgID, code)

		// Assert
		assert.False(t, result.Success())
		assert.NotNil(t, result.Error())
		assert.Equal(t, gorm.ErrRecordNotFound, result.Error())
		assert.Nil(t, result.Value())
	})

	t.Run("should handle database connection error", func(t *testing.T) {
		// Setup
		db, mock, cleanup := setupMockDB(t)
		defer cleanup()

		orgID := "org123"
		code := "api_calls"
		dbError := errors.New("database connection failed")

		// Expect the query but return error
		mock.ExpectQuery(fetchBillableMetricQuery).
			WithArgs(orgID, code, 1).
			WillReturnError(dbError)

		// Execute
		result := db.FetchBillableMetric(orgID, code)

		// Assert
		assert.False(t, result.Success())
		assert.NotNil(t, result.Error())
		assert.Equal(t, dbError, result.Error())
		assert.Nil(t, result.Value())
	})
}
