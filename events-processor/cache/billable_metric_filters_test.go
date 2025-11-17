package cache

import (
	"testing"

	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/utils"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestBuildBillableMetricFilterKey(t *testing.T) {
	cache := setupTestCache(t)

	testModel := struct {
		id               string
		organizationID   string
		billableMetricID string
	}{
		id:               "123",
		organizationID:   "org-123",
		billableMetricID: "bm-123",
	}

	expectedKey := "bmf:org-123:bm-123:123"
	key := cache.buildBillableMetricFilterKey(testModel.organizationID, testModel.billableMetricID, testModel.id)
	assert.Equal(t, expectedKey, key)
}

func TestSetBillableMetricFilter_Success(t *testing.T) {
	cache := setupTestCache(t)

	bmf := &models.BillableMetricFilter{
		ID:               "123",
		OrganizationID:   "org-123",
		BillableMetricID: "bm-123",
		Key:              "region",
		Values:           []string{"us-east-1", "eu-west-1"},
		CreatedAt:        utils.NowNullTime(),
		UpdatedAt:        utils.NowNullTime(),
	}

	result := cache.SetBillableMetricFilter(bmf)

	assert.True(t, result.Success())
	assert.True(t, result.Value())
}

func TestGetBillableMetricFilter_Success(t *testing.T) {
	cache := setupTestCache(t)

	bmf := &models.BillableMetricFilter{
		ID:               "123",
		OrganizationID:   "org-123",
		BillableMetricID: "bm-123",
		Key:              "region",
		Values:           []string{"us-east-1"},
		CreatedAt:        utils.NowNullTime(),
		UpdatedAt:        utils.NowNullTime(),
	}

	cache.SetBillableMetricFilter(bmf)

	result := cache.GetBillableMetricFilter("org-123", "bm-123", "123")

	require.True(t, result.Success())
	retrieved := result.Value()
	assert.Equal(t, bmf.ID, retrieved.ID)
	assert.Equal(t, bmf.OrganizationID, retrieved.OrganizationID)
	assert.Equal(t, bmf.BillableMetricID, retrieved.BillableMetricID)
	assert.Equal(t, bmf.Key, retrieved.Key)
}

func TestGetBillableMetricFilter_NotFound(t *testing.T) {
	cache := setupTestCache(t)

	result := cache.GetBillableMetricFilter("notorg", "bm-123", "123")

	assert.True(t, result.Failure())
}
