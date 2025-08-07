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

		pricingGroupKeys := []string{"country", "region"}
		pricingGroupKeysJSON, _ := json.Marshal(pricingGroupKeys)

		// Define expected rows and columns
		columns := []string{"organization_id", "billable_metric_code", "plan_id", "charge_id", "charge_updated_at", "charge_filter_id", "charge_filter_updated_at", "filters", "pricing_group_keys"}
		rows := sqlmock.NewRows(columns).
			AddRow("1a901a90-1a90-1a90-1a90-1a901a901a90", code, planID, "1a901a90-1a90-1a90-1a90-1a901a901a90", now, "1a901a90-1a90-1a90-1a90-1a901a901a90", now, filtersJSON, pricingGroupKeysJSON)

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

		assert.Equal(t, pricingGroupKeys, []string(flatFilter.PricingGroupKeys))
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

func TestHasFilters(t *testing.T) {
	t.Run("should check the presence of filters", func(t *testing.T) {
		flatFilter := FlatFilter{}
		assert.False(t, flatFilter.HasFilters())

		flatFilter.Filters = &FlatFilterValues{}
		assert.False(t, flatFilter.HasFilters())

		(*flatFilter.Filters)["scheme"] = []string{"visa", "mastercard"}
		assert.True(t, flatFilter.HasFilters())
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

		result := flatFilter.IsMatchingEvent(&event)

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

		result := flatFilter.IsMatchingEvent(&event)

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

		result := flatFilter.IsMatchingEvent(&event)

		assert.False(t, result.Value())
	})

	t.Run("should return true if filters are empty", func(t *testing.T) {
		event := EnrichedEvent{
			Properties: map[string]any{"scheme": "visa", "payment_method": "debit"},
		}

		flatFilter := FlatFilter{
			Filters: nil,
		}

		result := flatFilter.IsMatchingEvent(&event)

		assert.True(t, result.Value())
	})
}

func TestToDefaultFilter(t *testing.T) {
	t.Run("should return only the charge default filter", func(t *testing.T) {
		now := time.Now()
		chargeFilterId := "charge_filter_id"

		flatFilter := &FlatFilter{
			OrganizationID:        "org_id",
			BillableMetricCode:    "api_call",
			PlanID:                "plan_id",
			ChargeID:              "charge_id",
			ChargeUpdatedAt:       now,
			ChargeFilterID:        &chargeFilterId,
			ChargeFilterUpdatedAt: &now,
			Filters: &FlatFilterValues{
				"scheme":         {"visa", "mastercard"},
				"payment_method": {"debit"},
			},
		}

		filter := flatFilter.ToDefaultFilter()
		assert.Equal(t, filter.OrganizationID, flatFilter.OrganizationID)
		assert.Equal(t, filter.BillableMetricCode, flatFilter.BillableMetricCode)
		assert.Equal(t, filter.PlanID, flatFilter.PlanID)
		assert.Equal(t, filter.ChargeID, flatFilter.ChargeID)
		assert.Equal(t, filter.ChargeUpdatedAt, flatFilter.ChargeUpdatedAt)
		assert.Nil(t, filter.ChargeFilterID)
		assert.Nil(t, filter.ChargeFilterUpdatedAt)
		assert.Nil(t, filter.Filters)
	})
}

func TestMatchingFilter(t *testing.T) {
	t.Run("it should return the default charge with a single filter", func(t *testing.T) {
		event := EnrichedEvent{
			Properties: map[string]any{},
		}

		now := time.Now()

		flatFilter := &FlatFilter{
			OrganizationID:     "org_id",
			BillableMetricCode: "api_call",
			PlanID:             "plan_id",
			ChargeID:           "charge_id",
			ChargeUpdatedAt:    now,
			Filters:            &FlatFilterValues{},
		}

		result := MatchingFilter([]FlatFilter{*flatFilter}, &event)

		assert.Equal(t, result.OrganizationID, flatFilter.OrganizationID)
		assert.Equal(t, result.BillableMetricCode, flatFilter.BillableMetricCode)
		assert.Equal(t, result.PlanID, flatFilter.PlanID)
		assert.Equal(t, result.ChargeID, flatFilter.ChargeID)
		assert.Equal(t, result.ChargeUpdatedAt, flatFilter.ChargeUpdatedAt)
		assert.Nil(t, result.ChargeFilterID)
		assert.Nil(t, result.ChargeFilterUpdatedAt)
		assert.Nil(t, result.Filters)
	})

	t.Run("it should return the default charge with a single non matching filter", func(t *testing.T) {
		event := EnrichedEvent{
			Properties: map[string]any{"scheme": "maestro"},
		}

		now := time.Now()
		chargeFilterId := "charge_filter_id"

		flatFilter := &FlatFilter{
			OrganizationID:        "org_id",
			BillableMetricCode:    "api_call",
			PlanID:                "plan_id",
			ChargeID:              "charge_id",
			ChargeUpdatedAt:       now,
			ChargeFilterID:        &chargeFilterId,
			ChargeFilterUpdatedAt: &now,
			Filters:               &FlatFilterValues{"scheme": []string{"mastercard", "visa"}},
		}

		result := MatchingFilter([]FlatFilter{*flatFilter}, &event)

		assert.Equal(t, result.OrganizationID, flatFilter.OrganizationID)
		assert.Equal(t, result.BillableMetricCode, flatFilter.BillableMetricCode)
		assert.Equal(t, result.PlanID, flatFilter.PlanID)
		assert.Equal(t, result.ChargeID, flatFilter.ChargeID)
		assert.Equal(t, result.ChargeUpdatedAt, flatFilter.ChargeUpdatedAt)
		assert.Nil(t, result.ChargeFilterID)
		assert.Nil(t, result.ChargeFilterUpdatedAt)
		assert.Nil(t, result.Filters)
	})

	t.Run("it should return the single matching filter when matching", func(t *testing.T) {
		event := EnrichedEvent{
			Properties: map[string]any{"scheme": "visa"},
		}

		now := time.Now()
		chargeFilterId := "charge_filter_id"

		flatFilter := &FlatFilter{
			OrganizationID:        "org_id",
			BillableMetricCode:    "api_call",
			PlanID:                "plan_id",
			ChargeID:              "charge_id",
			ChargeUpdatedAt:       now,
			ChargeFilterID:        &chargeFilterId,
			ChargeFilterUpdatedAt: &now,
			Filters:               &FlatFilterValues{"scheme": []string{"mastercard", "visa"}},
		}

		result := MatchingFilter([]FlatFilter{*flatFilter}, &event)

		assert.Equal(t, result, flatFilter)
	})

	t.Run("it should return the default charge when no matching filters", func(t *testing.T) {
		event := EnrichedEvent{
			Properties: map[string]any{"scheme": "maestro"},
		}

		now := time.Now()
		chargeFilterId1 := "charge_filter_id1"
		chargeFilterId2 := "charge_filter_id2"

		flatFilter1 := &FlatFilter{
			OrganizationID:        "org_id",
			BillableMetricCode:    "api_call",
			PlanID:                "plan_id",
			ChargeID:              "charge_id",
			ChargeUpdatedAt:       now,
			ChargeFilterID:        &chargeFilterId1,
			ChargeFilterUpdatedAt: &now,
			Filters:               &FlatFilterValues{"scheme": []string{"visa"}},
		}

		flatFilter2 := &FlatFilter{
			OrganizationID:        "org_id",
			BillableMetricCode:    "api_call",
			PlanID:                "plan_id",
			ChargeID:              "charge_id",
			ChargeUpdatedAt:       now,
			ChargeFilterID:        &chargeFilterId2,
			ChargeFilterUpdatedAt: &now,
			Filters:               &FlatFilterValues{"scheme": []string{"mastercard"}},
		}

		result := MatchingFilter([]FlatFilter{*flatFilter1, *flatFilter2}, &event)

		assert.Equal(t, result.OrganizationID, flatFilter1.OrganizationID)
		assert.Equal(t, result.BillableMetricCode, flatFilter1.BillableMetricCode)
		assert.Equal(t, result.PlanID, flatFilter1.PlanID)
		assert.Equal(t, result.ChargeID, flatFilter1.ChargeID)
		assert.Equal(t, result.ChargeUpdatedAt, flatFilter1.ChargeUpdatedAt)
		assert.Nil(t, result.ChargeFilterID)
		assert.Nil(t, result.ChargeFilterUpdatedAt)
		assert.Nil(t, result.Filters)
	})

	t.Run("it should return the matching filter", func(t *testing.T) {
		event := EnrichedEvent{
			Properties: map[string]any{"scheme": "mastercard"},
		}

		now := time.Now()
		chargeFilterId1 := "charge_filter_id1"
		chargeFilterId2 := "charge_filter_id2"

		flatFilter1 := &FlatFilter{
			OrganizationID:        "org_id",
			BillableMetricCode:    "api_call",
			PlanID:                "plan_id",
			ChargeID:              "charge_id",
			ChargeUpdatedAt:       now,
			ChargeFilterID:        &chargeFilterId1,
			ChargeFilterUpdatedAt: &now,
			Filters:               &FlatFilterValues{"scheme": []string{"visa"}},
		}

		flatFilter2 := &FlatFilter{
			OrganizationID:        "org_id",
			BillableMetricCode:    "api_call",
			PlanID:                "plan_id",
			ChargeID:              "charge_id",
			ChargeUpdatedAt:       now,
			ChargeFilterID:        &chargeFilterId2,
			ChargeFilterUpdatedAt: &now,
			Filters:               &FlatFilterValues{"scheme": []string{"mastercard"}},
		}

		result := MatchingFilter([]FlatFilter{*flatFilter1, *flatFilter2}, &event)

		assert.Equal(t, result, flatFilter2)
	})

	t.Run("it should return the best matching filter when multiple matching filters", func(t *testing.T) {
		event := EnrichedEvent{
			Properties: map[string]any{"scheme": "mastercard", "method": "debit"},
		}

		now := time.Now()
		chargeFilterId1 := "charge_filter_id1"
		chargeFilterId2 := "charge_filter_id2"

		flatFilter1 := &FlatFilter{
			OrganizationID:        "org_id",
			BillableMetricCode:    "api_call",
			PlanID:                "plan_id",
			ChargeID:              "charge_id",
			ChargeUpdatedAt:       now,
			ChargeFilterID:        &chargeFilterId1,
			ChargeFilterUpdatedAt: &now,
			Filters:               &FlatFilterValues{"scheme": []string{"mastercard"}},
		}

		flatFilter2 := &FlatFilter{
			OrganizationID:        "org_id",
			BillableMetricCode:    "api_call",
			PlanID:                "plan_id",
			ChargeID:              "charge_id",
			ChargeUpdatedAt:       now,
			ChargeFilterID:        &chargeFilterId2,
			ChargeFilterUpdatedAt: &now,
			Filters:               &FlatFilterValues{"scheme": []string{"mastercard"}, "method": []string{"debit", "credit"}},
		}

		result := MatchingFilter([]FlatFilter{*flatFilter1, *flatFilter2}, &event)

		assert.Equal(t, result, flatFilter2)
	})
}
