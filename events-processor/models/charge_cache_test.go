package models

import (
	"testing"
	"time"

	"github.com/getlago/lago/events-processor/tests"
	"github.com/getlago/lago/events-processor/utils"
	"github.com/stretchr/testify/assert"
)

func TestExpireChargeCache(t *testing.T) {
	t.Run("should expire a cache key without FilterID", func(t *testing.T) {
		timeStr := "2025-03-03T13:03:29"
		updatedAt, _ := time.Parse("2006-01-02T15:04:05", timeStr)

		chargeFilter := FlatFilter{
			OrganizationID:     "org_1a901a90-1a90-1a90-1a90-1a901a901a90",
			BillableMetricCode: "api_call",
			PlanID:             "plan_1a901a90-1a90-1a90-1a90-1a901a901a90",
			ChargeID:           "charge_id",
			ChargeUpdatedAt:    updatedAt,
		}
		subID := "sub_id"

		cacheStore := &tests.MockCacheStore{
			ReturnedResult: utils.SuccessResult(true),
		}

		var cache Cacher = cacheStore
		chargeCache := NewChargeCache(&cache)

		result := chargeCache.Expire(&chargeFilter, subID)

		assert.True(t, result.Success())
		assert.Equal(t, cacheStore.LastKey, "charge-usage/1/charge_id/sub_id/2025-03-03T13:03:29Z")
	})

	t.Run("should expire a cache key with FilterID", func(t *testing.T) {
		timeStr := "2025-03-03T13:03:29"
		updatedAt, _ := time.Parse("2006-01-02T15:04:05", timeStr)

		filterID := "filter_id"

		chargeFilter := FlatFilter{
			OrganizationID:        "org_1a901a90-1a90-1a90-1a90-1a901a901a90",
			BillableMetricCode:    "api_call",
			PlanID:                "plan_1a901a90-1a90-1a90-1a90-1a901a901a90",
			ChargeID:              "charge_id",
			ChargeUpdatedAt:       updatedAt,
			ChargeFilterID:        &filterID,
			ChargeFilterUpdatedAt: &updatedAt,
		}
		subID := "sub_id"

		cacheStore := &tests.MockCacheStore{
			ReturnedResult: utils.SuccessResult(true),
		}

		var cache Cacher = cacheStore
		chargeCache := NewChargeCache(&cache)

		result := chargeCache.Expire(&chargeFilter, subID)

		assert.True(t, result.Success())
		assert.Equal(t, cacheStore.LastKey, "charge-usage/1/charge_id/sub_id/2025-03-03T13:03:29Z/filter_id/2025-03-03T13:03:29Z")
	})
}
