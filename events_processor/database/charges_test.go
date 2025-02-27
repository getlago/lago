package database

import (
	"errors"
	"regexp"
	"testing"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/stretchr/testify/assert"
)

var anyInAdvanceChargeQuery = regexp.QuoteMeta(`
	SELECT count(*) FROM "charges"
	WHERE (plan_id = $1 AND billable_metric_id = $2)
	AND pay_in_advance = true
	AND "charges"."deleted_at" IS NULL`,
)

func TestAnyInAdvanceCharge(t *testing.T) {
	t.Run("should return true when in advance charge exists", func(t *testing.T) {
		// Setup
		db, mock, cleanup := setupMockDB(t)
		defer cleanup()

		planID := "1a901a90-1a90-1a90-1a90-1a901a901a90"
		bmID := "1a901a90-1a90-1a90-1a90-1a901a901a91"

		countRows := sqlmock.NewRows([]string{"count"}).AddRow(3)

		// Expect the query but return error
		mock.ExpectQuery(anyInAdvanceChargeQuery).
			WithArgs(planID, bmID).
			WillReturnRows(countRows)

		// Execute
		result := db.AnyInAdvanceCharge(planID, bmID)

		// Assert
		assert.True(t, result.Success())
		assert.Equal(t, true, result.Value())
	})

	t.Run("should return false when no in advance charge exists", func(t *testing.T) {
		// Setup
		db, mock, cleanup := setupMockDB(t)
		defer cleanup()

		planID := "1a901a90-1a90-1a90-1a90-1a901a901a90"
		bmID := "1a901a90-1a90-1a90-1a90-1a901a901a91"

		countRows := sqlmock.NewRows([]string{"count"}).AddRow(0)

		// Expect the query but return error
		mock.ExpectQuery(anyInAdvanceChargeQuery).
			WithArgs(planID, bmID).
			WillReturnRows(countRows)

		// Execute
		result := db.AnyInAdvanceCharge(planID, bmID)

		// Assert
		assert.True(t, result.Success())
		assert.Equal(t, false, result.Value())
	})

	t.Run("should handle database connection error", func(t *testing.T) {
		// Setup
		db, mock, cleanup := setupMockDB(t)
		defer cleanup()

		planID := "1a901a90-1a90-1a90-1a90-1a901a901a90"
		bmID := "1a901a90-1a90-1a90-1a90-1a901a901a91"
		dbError := errors.New("database connection failed")

		// Expect the query but return error
		mock.ExpectQuery(anyInAdvanceChargeQuery).
			WithArgs(planID, bmID).
			WillReturnError(dbError)

		// Execute
		result := db.AnyInAdvanceCharge(planID, bmID)

		// Assert
		assert.False(t, result.Success())
		assert.NotNil(t, result.Error())
		assert.Equal(t, dbError, result.Error())
		assert.False(t, result.Value())
	})
}
