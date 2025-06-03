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

func TestFilterKeys(t *testing.T) {
	t.Run("should extract all keys from the Filters", func(t *testing.T) {
		filters := FlatFilterValues{
			"scheme":         {"visa", "mastercard"},
			"payment_method": {"debit"},
		}

		keys := filters.Keys()
		assert.ElementsMatch(t, []string{"scheme", "payment_method"}, keys)
	})

}

func TestIsMatchingEvent(t *testing.T) {
	t.Run("should match events properties with valid filters", func(t *testing.T) {
		event := EnrichedEvent{
			Properties: map[string]any{"scheme": "visa", "payment_method": "debit"},
		}

		flatFilter := FlatFilter{
			Filters: &FlatFilterValues{
				"scheme":         {"visa", "mastercard"},
				"payment_method": {"debit"},
			},
		}

		result := flatFilter.IsMatchingEvent(event)

		assert.True(t, result.Value())
	})

	t.Run("should not match events properties with invalid filters", func(t *testing.T) {
		event := EnrichedEvent{
			Properties: map[string]any{"scheme": "visa", "payment_method": "debit"},
		}

		flatFilter := FlatFilter{
			Filters: &FlatFilterValues{
				"scheme":         {"visa", "mastercard"},
				"payment_method": {"credit"},
			},
		}

		result := flatFilter.IsMatchingEvent(event)

		assert.False(t, result.Value())
	})

	t.Run("should not match events properties with missing filters", func(t *testing.T) {
		event := EnrichedEvent{
			Properties: map[string]any{"scheme": "visa", "payment_method": "debit"},
		}

		flatFilter := FlatFilter{
			Filters: &FlatFilterValues{
				"scheme":         {"visa", "mastercard"},
				"payment_method": {"debit"},
				"country":        {"us"},
			},
		}

		result := flatFilter.IsMatchingEvent(event)

		assert.False(t, result.Value())
	})

	t.Run("should return true if filters are empty", func(t *testing.T) {
		event := EnrichedEvent{
			Properties: map[string]any{"scheme": "visa", "payment_method": "debit"},
		}

		flatFilter := FlatFilter{
			Filters: nil,
		}

		result := flatFilter.IsMatchingEvent(event)

		assert.True(t, result.Value())
	})
}
