package cache

import (
	"testing"

	"github.com/getlago/lago/events-processor/models"
	"github.com/stretchr/testify/assert"
)

func TestBuildChargeFilterValueKey(t *testing.T) {
	cache := setupTestCache(t)

	testModel := struct {
		id                     string
		organizationID         string
		chargeFilterID         string
		billableMetricFilterID string
	}{
		id:                     "123",
		organizationID:         "org-123",
		chargeFilterID:         "chf-123",
		billableMetricFilterID: "bm-123",
	}

	expectedKey := "cfv:org-123:chf-123:bm-123:123"
	key := cache.buildChargeFilterValueKey(testModel.organizationID, testModel.chargeFilterID, testModel.billableMetricFilterID, testModel.id)
	assert.Equal(t, expectedKey, key)
}

func TestSetChargeFilterValue_Success(t *testing.T) {
	cache := setupTestCache(t)

	cfv := &models.ChargeFilterValue{
		ID:                     "123",
		OrganizationID:         "org-123",
		ChargeFilterID:         "chf-123",
		BillableMetricFilterID: "bm-123",
	}

	result := cache.SetChargeFilterValue(cfv)

	assert.True(t, result.Success())
	assert.True(t, result.Value())
}

func TestGetChargeFilterValue_Success(t *testing.T) {
	cache := setupTestCache(t)

	cfv := &models.ChargeFilterValue{
		ID:                     "123",
		OrganizationID:         "org-123",
		ChargeFilterID:         "chf-123",
		BillableMetricFilterID: "bm-123",
	}

	cache.SetChargeFilterValue(cfv)

	result := cache.GetChargeFilterValue("org-123", "chf-123", "bm-123", "123")

	assert.True(t, result.Success())
	assert.Equal(t, cfv, result.Value())
}

func TestGetChargeFilterValue_NotFound(t *testing.T) {
	cache := setupTestCache(t)

	result := cache.GetChargeFilterValue("org-123", "chf-123", "bm-123", "123")

	assert.True(t, result.Failure())
}
