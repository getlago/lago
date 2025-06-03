package models

import (
	"encoding/json"
	"regexp"
	"testing"
	"time"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/stretchr/testify/assert"
)

var fetchFiltersQuery = regexp.QuoteMeta(`
	SELECT * FROM "flat_filters" WHERE plan_id = $1 AND billable_metric_code = $2`)

func TestFetchFlatFilters(t *testing.T) {
	t.Run("should return flat filters when found", func(t *testing.T) {
		// Setup
		store, mock, cleanup := setupApiStore(t)
		defer cleanup()

		code := "api_calls"
		planID := "1a901a90-1a90-1a90-1a90-1a901a901a90"
		now := time.Now()

		filters := map[string][]string{
			"scheme":         {"visa", "mastercard"},
			"payment_method": {"debit"},
		}

		// Convert filters to JSON for JSONB column
		filtersJSON, _ := json.Marshal(filters)

		// Define expected rows and columns
		columns := []string{"organization_id", "billable_metric_code", "plan_id", "charge_id", "charge_updated_at", "charge_filter_id", "charge_filter_updated_at", "filters"}
		rows := sqlmock.NewRows(columns).
			AddRow("1a901a90-1a90-1a90-1a90-1a901a901a90", code, planID, "1a901a90-1a90-1a90-1a90-1a901a901a90", now, "1a901a90-1a90-1a90-1a90-1a901a901a90", now, filtersJSON)

		// Expect the query
		mock.ExpectQuery(fetchFiltersQuery).
			WithArgs(planID, code).
			WillReturnRows(rows)

		result := store.FetchFlatFilters(planID, code)

		// Assert
		assert.True(t, result.Success())
		assert.Len(t, result.Value(), 1)

		flatFilter := result.Value()[0]
		assert.NotNil(t, flatFilter.Filters)

		// Convert FilterMap back to regular map for comparison
		actualFilters := map[string][]string(*flatFilter.Filters)
		assert.Equal(t, filters, actualFilters)
	})

	t.Run("should return an empty result when not found", func(t *testing.T) {
		// Setup
		store, mock, cleanup := setupApiStore(t)
		defer cleanup()

		code := "api_calls"
		planID := "1a901a90-1a90-1a90-1a90-1a901a901a90"

		// Define expected rows and columns
		columns := []string{"organization_id", "billable_metric_code", "plan_id", "charge_id", "charge_updated_at", "charge_filter_id", "charge_filter_updated_at", "filters"}
		rows := sqlmock.NewRows(columns)

		// Expect the query
		mock.ExpectQuery(fetchFiltersQuery).
			WithArgs(planID, code).
			WillReturnRows(rows)

		result := store.FetchFlatFilters(planID, code)

		// Assert
		assert.True(t, result.Success())
		assert.Len(t, result.Value(), 0)
	})
}
