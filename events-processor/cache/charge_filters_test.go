package cache

import (
	"testing"

	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/utils"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestBuildChargeFilterKey(t *testing.T) {
	cache := setupTestCache(t)

	testModel := struct {
		id                     string
		organizationID         string
		chargeID               string
		billableMetricFilterID string
	}{
		id:                     "123",
		organizationID:         "org-123",
		chargeID:               "ch-123",
		billableMetricFilterID: "bmf-123",
	}

	expectedKey := "cf:org-123:ch-123:bmf-123:123"
	key := cache.buildChargeFilterKey(testModel.organizationID, testModel.chargeID, testModel.billableMetricFilterID, testModel.id)
	assert.Equal(t, expectedKey, key)
}

func TestSetChargeFilter_Success(t *testing.T) {
	cache := setupTestCache(t)

	cf := &models.ChargeFilter{
		ID:                     "123",
		OrganizationID:         "org-123",
		ChargeID:               "ch-123",
		BillableMetricFilterID: "bmf-123",
		Values:                 []string{"us-east-1", "eu-west-1"},
		CreatedAt:              utils.NowNullTime(),
		UpdatedAt:              utils.NowNullTime(),
	}

	result := cache.SetChargeFilter(cf)

	assert.True(t, result.Success())
	assert.True(t, result.Value())
}

func TestGetChargeFilter_Success(t *testing.T) {
	cache := setupTestCache(t)

	cf := &models.ChargeFilter{
		ID:                     "123",
		OrganizationID:         "org-123",
		ChargeID:               "ch-123",
		BillableMetricFilterID: "bmf-123",
		Values:                 []string{"us-east-1"},
		CreatedAt:              utils.NowNullTime(),
		UpdatedAt:              utils.NowNullTime(),
	}

	cache.SetChargeFilter(cf)

	result := cache.GetChargeFilter("org-123", "ch-123", "bmf-123", "123")

	require.True(t, result.Success())
	retrieved := result.Value()
	assert.Equal(t, cf.ID, retrieved.ID)
	assert.Equal(t, cf.OrganizationID, retrieved.OrganizationID)
	assert.Equal(t, cf.ChargeID, retrieved.ChargeID)
	assert.Equal(t, cf.BillableMetricFilterID, retrieved.BillableMetricFilterID)
}

func TestGetChargeFilter_NotFound(t *testing.T) {
	cache := setupTestCache(t)

	result := cache.GetChargeFilter("notorg", "notch", "notbmf", "123")

	assert.True(t, result.Failure())
}
