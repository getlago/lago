package cache

import (
	"testing"

	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/utils"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestBuildBillableMetricKey(t *testing.T) {
	cache := setupTestCache(t)

	tests := []struct {
		name           string
		organizationID string
		code           string
		expectedKey    string
	}{
		{
			name:           "standard key",
			organizationID: "org-123",
			code:           "api_calls",
			expectedKey:    "bm:org-123:api_calls",
		},
		{
			name:           "with special characters",
			organizationID: "org-456",
			code:           "cpu_usage_hrs",
			expectedKey:    "bm:org-456:cpu_usage_hrs",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			key := cache.buildBillableMetricKey(tt.organizationID, tt.code)
			assert.Equal(t, tt.expectedKey, key)
		})
	}
}

func TestSetBillableMetric_Success(t *testing.T) {
	cache := setupTestCache(t)

	bm := &models.BillableMetric{
		ID:              "bm-123",
		OrganizationID:  "org-123",
		Code:            "api_calls",
		AggregationType: models.AggregationTypeCount,
		FieldName:       "",
		CreatedAt:       utils.NowNullTime(),
		UpdatedAt:       utils.NowNullTime(),
		DeletedAt:       utils.NullTime{},
	}

	result := cache.SetBillableMetric(bm)

	assert.True(t, result.Success())
	assert.True(t, result.Value())
}

func TestGetBillableMetric_Success(t *testing.T) {
	cache := setupTestCache(t)

	bm := &models.BillableMetric{
		ID:              "bm-123",
		OrganizationID:  "org-123",
		Code:            "requests",
		AggregationType: models.AggregationTypeCount,
		CreatedAt:       utils.NowNullTime(),
		UpdatedAt:       utils.NowNullTime(),
	}

	cache.SetBillableMetric(bm)

	result := cache.GetBillableMetric("org-123", "requests")

	require.True(t, result.Success())
	retrieved := result.Value()
	assert.Equal(t, bm.ID, retrieved.ID)
	assert.Equal(t, bm.Code, retrieved.Code)
}

func TestGetBillableMetric_NotFound(t *testing.T) {
	cache := setupTestCache(t)

	result := cache.GetBillableMetric("org-123", "nonexistdent")

	assert.True(t, result.Failure())
}
