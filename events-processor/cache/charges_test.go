package cache

import (
	"testing"

	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/utils"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestBuildChargeKey(t *testing.T) {
	cache := setupTestCache(t)

	testModel := struct {
		id               string
		organizationID   string
		planID           string
		billableMetricID string
	}{
		id:               "123",
		organizationID:   "org-123",
		planID:           "plan-123",
		billableMetricID: "bm-123",
	}

	expectedKey := "ch:org-123:plan-123:bm-123:123"
	key := cache.buildChargeKey(testModel.organizationID, testModel.planID, testModel.billableMetricID, testModel.id)
	assert.Equal(t, expectedKey, key)
}

func TestSetCharge_Success(t *testing.T) {
	cache := setupTestCache(t)

	ch := &models.Charge{
		ID:               "123",
		OrganizationID:   "org-123",
		PlanID:           "plan-123",
		BillableMetricID: "bm-123",
		CreatedAt:        utils.NowNullTime(),
		UpdatedAt:        utils.NowNullTime(),
	}

	result := cache.SetCharge(ch)

	assert.True(t, result.Success())
	assert.True(t, result.Value())
}

func TestGetCharge_Success(t *testing.T) {
	cache := setupTestCache(t)

	ch := &models.Charge{
		ID:               "123",
		OrganizationID:   "org-123",
		PlanID:           "plan-123",
		BillableMetricID: "bm-123",
		CreatedAt:        utils.NowNullTime(),
		UpdatedAt:        utils.NowNullTime(),
	}

	cache.SetCharge(ch)

	result := cache.GetCharge("org-123", "plan-123", "bm-123", "123")

	require.True(t, result.Success())
	retrieved := result.Value()
	assert.Equal(t, ch.ID, retrieved.ID)
}

func TestGetCharge_NotFound(t *testing.T) {
	cache := setupTestCache(t)

	result := cache.GetCharge("org1", "plan1", "bm1", "123")

	assert.True(t, result.Failure())
}

func TestHasPayInAdvanceCharge(t *testing.T) {
	t.Run("Without any charge", func(t *testing.T) {
		cache := setupTestCache(t)

		result := cache.HasPayInAdvanceCharge("org-123", "plan-123", "bm-123")

		require.True(t, result.Success())
		assert.False(t, result.Value())
	})

	t.Run("When no charge is charged in advance", func(t *testing.T) {
		cache := setupTestCache(t)

		cache.SetCharge(&models.Charge{
			ID:               "123",
			OrganizationID:   "org-123",
			PlanID:           "plan-123",
			BillableMetricID: "bm-123",
			PayInAdvance:     false,
			CreatedAt:        utils.NowNullTime(),
			UpdatedAt:        utils.NowNullTime(),
		})

		result := cache.HasPayInAdvanceCharge("org-123", "plan-123", "bm-123")

		require.True(t, result.Success())
		assert.False(t, result.Value())
	})

	t.Run("When one charge out of many is charged in advance", func(t *testing.T) {
		cache := setupTestCache(t)

		cache.SetCharge(&models.Charge{
			ID:               "123",
			OrganizationID:   "org-123",
			PlanID:           "plan-123",
			BillableMetricID: "bm-123",
			PayInAdvance:     false,
			CreatedAt:        utils.NowNullTime(),
			UpdatedAt:        utils.NowNullTime(),
		})
		cache.SetCharge(&models.Charge{
			ID:               "456",
			OrganizationID:   "org-123",
			PlanID:           "plan-123",
			BillableMetricID: "bm-123",
			PayInAdvance:     true,
			CreatedAt:        utils.NowNullTime(),
			UpdatedAt:        utils.NowNullTime(),
		})

		result := cache.HasPayInAdvanceCharge("org-123", "plan-123", "bm-123")

		require.True(t, result.Success())
		assert.True(t, result.Value())
	})

	t.Run("When the charge belongs to another plan", func(t *testing.T) {
		cache := setupTestCache(t)

		cache.SetCharge(&models.Charge{
			ID:               "123",
			OrganizationID:   "org-123",
			PlanID:           "other-plan",
			BillableMetricID: "bm-123",
			PayInAdvance:     true,
			CreatedAt:        utils.NowNullTime(),
			UpdatedAt:        utils.NowNullTime(),
		})

		result := cache.HasPayInAdvanceCharge("org-123", "plan-123", "bm-123")

		require.True(t, result.Success())
		assert.False(t, result.Value())
	})
}
