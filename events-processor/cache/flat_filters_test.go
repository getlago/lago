package cache

import (
	"fmt"
	"testing"

	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/utils"
	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestBuildFlatFilters_NoChargeFilters(t *testing.T) {
	cache := setupTestCache(t)

	orgID := uuid.New().String()
	bmCode := "test_metric"
	bmID := uuid.New().String()
	planID := uuid.New().String()
	chargeID := uuid.New().String()

	bm := &models.BillableMetric{
		ID:             bmID,
		OrganizationID: orgID,
		Code:           bmCode,
	}
	result := cache.SetBillableMetric(bm)
	require.True(t, result.Success())

	charge := &models.Charge{
		ID:               chargeID,
		OrganizationID:   orgID,
		PlanID:           planID,
		BillableMetricID: bmID,
		UpdatedAt:        utils.NowNullTime(),
		PricingGroupKeys: []string{"region", "country"},
		PayInAdvance:     true,
	}
	result = cache.SetCharge(charge)
	require.True(t, result.Success())

	ffResult := cache.BuildFlatFilters(orgID, bmCode, planID)
	require.True(t, ffResult.Success())

	flatFilters := ffResult.Value()
	require.Len(t, flatFilters, 1)

	ff := flatFilters[0]
	assert.Equal(t, orgID, ff.OrganizationID)
	assert.Equal(t, bmCode, ff.BillableMetricCode)
	assert.Equal(t, planID, ff.PlanID)
	assert.Equal(t, chargeID, ff.ChargeID)
	assert.Nil(t, ff.ChargeFilterID)
	assert.Nil(t, ff.ChargeFilterUpdatedAt)
	assert.Nil(t, ff.Filters)
	assert.True(t, ff.PayInAdvance)
	assert.Equal(t, models.PricingGroupKeys{"region", "country"}, ff.PricingGroupKeys)
}

func TestBuildFlatFilters_WithChargeFilters(t *testing.T) {
	cache := setupTestCache(t)

	orgID := uuid.New().String()
	bmCode := "test_metric"
	bmID := uuid.New().String()
	planID := uuid.New().String()
	chargeID := uuid.New().String()
	chargeFilterID := uuid.New().String()
	bmFilterID1 := uuid.New().String()
	bmFilterID2 := uuid.New().String()

	bm := &models.BillableMetric{
		ID:             bmID,
		OrganizationID: orgID,
		Code:           bmCode,
	}
	result := cache.SetBillableMetric(bm)
	require.True(t, result.Success())

	bmf1 := &models.BillableMetricFilter{
		ID:               bmFilterID1,
		OrganizationID:   orgID,
		BillableMetricID: bmID,
		Key:              "region",
		Values:           []string{"us-east", "us-west", "eu-west"},
	}
	result = cache.SetBillableMetricFilter(bmf1)
	require.True(t, result.Success())

	bmf2 := &models.BillableMetricFilter{
		ID:               bmFilterID2,
		OrganizationID:   orgID,
		BillableMetricID: bmID,
		Key:              "tier",
		Values:           []string{"standard", "premium"},
	}
	result = cache.SetBillableMetricFilter(bmf2)
	require.True(t, result.Success())

	charge := &models.Charge{
		ID:               chargeID,
		OrganizationID:   orgID,
		PlanID:           planID,
		BillableMetricID: bmID,
		UpdatedAt:        utils.NowNullTime(),
		PricingGroupKeys: []string{"region"},
		PayInAdvance:     false,
	}
	result = cache.SetCharge(charge)
	require.True(t, result.Success())

	chargeFilter := &models.ChargeFilter{
		ID:               chargeFilterID,
		OrganizationID:   orgID,
		ChargeID:         chargeID,
		UpdatedAt:        utils.NowNullTime(),
		PricingGroupKeys: []string{"region", "tier"},
	}
	result = cache.SetChargeFilter(chargeFilter)
	require.True(t, result.Success())

	cfv1 := &models.ChargeFilterValue{
		ID:                     uuid.New().String(),
		OrganizationID:         orgID,
		ChargeFilterID:         chargeFilterID,
		BillableMetricFilterID: bmFilterID1,
		Values:                 []string{"us-east", "us-west"},
	}
	result = cache.SetChargeFilterValue(cfv1)
	require.True(t, result.Success())

	cfv2 := &models.ChargeFilterValue{
		ID:                     uuid.New().String(),
		OrganizationID:         orgID,
		ChargeFilterID:         chargeFilterID,
		BillableMetricFilterID: bmFilterID2,
		Values:                 []string{"premium"},
	}
	result = cache.SetChargeFilterValue(cfv2)
	require.True(t, result.Success())

	ffResult := cache.BuildFlatFilters(orgID, bmCode, planID)
	require.True(t, ffResult.Success())

	flatFilters := ffResult.Value()
	require.Len(t, flatFilters, 1)

	ff := flatFilters[0]
	fmt.Printf("FLAT FILTER FILTERS: %v\n", ff.Filters)
	assert.Equal(t, orgID, ff.OrganizationID)
	assert.Equal(t, bmCode, ff.BillableMetricCode)
	assert.Equal(t, planID, ff.PlanID)
	assert.Equal(t, chargeID, ff.ChargeID)
	assert.NotNil(t, ff.ChargeFilterID)
	assert.Equal(t, chargeFilterID, *ff.ChargeFilterID)
	assert.NotNil(t, ff.Filters)
	assert.False(t, ff.PayInAdvance)

	filters := *ff.Filters
	assert.Equal(t, []string{"us-east", "us-west"}, filters["region"])
	assert.Equal(t, []string{"premium"}, filters["tier"])
	assert.Equal(t, models.PricingGroupKeys{"region", "tier"}, ff.PricingGroupKeys)
}

func TestBuildFlatFilters_WithAllFilterValues(t *testing.T) {
	cache := setupTestCache(t)

	orgID := uuid.New().String()
	bmCode := "test_metric"
	bmID := uuid.New().String()
	planID := uuid.New().String()
	chargeID := uuid.New().String()
	chargeFilterID := uuid.New().String()
	bmFilterID := uuid.New().String()

	bm := &models.BillableMetric{
		ID:             bmID,
		OrganizationID: orgID,
		Code:           bmCode,
	}
	result := cache.SetBillableMetric(bm)
	require.True(t, result.Success())

	bmf := &models.BillableMetricFilter{
		ID:               bmFilterID,
		OrganizationID:   orgID,
		BillableMetricID: bmID,
		Key:              "country",
		Values:           []string{"us", "uk", "fr", "de"},
	}
	result = cache.SetBillableMetricFilter(bmf)
	require.True(t, result.Success())

	charge := &models.Charge{
		ID:               chargeID,
		OrganizationID:   orgID,
		PlanID:           planID,
		BillableMetricID: bmID,
		UpdatedAt:        utils.NowNullTime(),
		PayInAdvance:     false,
	}
	result = cache.SetCharge(charge)
	require.True(t, result.Success())

	chargeFilter := &models.ChargeFilter{
		ID:             chargeFilterID,
		OrganizationID: orgID,
		ChargeID:       chargeID,
		UpdatedAt:      utils.NowNullTime(),
	}
	result = cache.SetChargeFilter(chargeFilter)
	require.True(t, result.Success())

	cfv := &models.ChargeFilterValue{
		ID:                     uuid.New().String(),
		OrganizationID:         orgID,
		ChargeFilterID:         chargeFilterID,
		BillableMetricFilterID: bmFilterID,
		Values:                 []string{"__ALL_FILTER_VALUES__"},
	}
	result = cache.SetChargeFilterValue(cfv)
	require.True(t, result.Success())

	ffResult := cache.BuildFlatFilters(orgID, bmCode, planID)
	require.True(t, ffResult.Success())

	flatFilters := ffResult.Value()
	require.Len(t, flatFilters, 1)

	ff := flatFilters[0]
	assert.NotNil(t, ff.Filters)

	filters := *ff.Filters
	assert.Equal(t, []string{"us", "uk", "fr", "de"}, filters["country"])
}

func TestBuildFlatFilters_BillableMetricNotFound(t *testing.T) {
	cache := setupTestCache(t)

	orgID := uuid.New().String()
	bmCode := "non_existent"
	planID := uuid.New().String()

	ffResult := cache.BuildFlatFilters(orgID, bmCode, planID)
	require.True(t, ffResult.Failure())
}

func TestBuildFlatFilters_MultipleCharges(t *testing.T) {
	cache := setupTestCache(t)

	orgID := uuid.New().String()
	bmCode := "test_metric"
	bmID := uuid.New().String()
	planID := uuid.New().String()
	chargeID1 := uuid.New().String()
	chargeID2 := uuid.New().String()

	bm := &models.BillableMetric{
		ID:             bmID,
		OrganizationID: orgID,
		Code:           bmCode,
	}
	result := cache.SetBillableMetric(bm)
	require.True(t, result.Success())

	charge1 := &models.Charge{
		ID:               chargeID1,
		OrganizationID:   orgID,
		PlanID:           planID,
		BillableMetricID: bmID,
		UpdatedAt:        utils.NowNullTime(),
		PayInAdvance:     true,
	}
	result = cache.SetCharge(charge1)
	require.True(t, result.Success())

	charge2 := &models.Charge{
		ID:               chargeID2,
		OrganizationID:   orgID,
		PlanID:           planID,
		BillableMetricID: bmID,
		UpdatedAt:        utils.NowNullTime(),
		PayInAdvance:     false,
	}
	result = cache.SetCharge(charge2)
	require.True(t, result.Success())

	ffResult := cache.BuildFlatFilters(orgID, bmCode, planID)
	require.True(t, ffResult.Success())

	flatFilters := ffResult.Value()
	require.Len(t, flatFilters, 2)

	chargeIDS := []string{flatFilters[0].ChargeID, flatFilters[1].ChargeID}
	assert.Contains(t, chargeIDS, chargeID1)
	assert.Contains(t, chargeIDS, chargeID2)
}
