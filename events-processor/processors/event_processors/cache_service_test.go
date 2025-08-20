package event_processors

import (
	"testing"
	"time"

	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/tests"
	"github.com/stretchr/testify/assert"
)

var cacheService *CacheService
var cacheStore tests.MockCacheStore

func setupCacheServiceEnv() {
	cacheStore = tests.MockCacheStore{}
	var chargeCache models.Cacher = &cacheStore
	chargeCacheStore := models.NewChargeCache(&chargeCache)
	cacheService = NewCacheService(chargeCacheStore)
}

func TestExpireCache(t *testing.T) {
	t.Run("With a single event", func(t *testing.T) {
		setupCacheServiceEnv()

		now := time.Now()
		chargeFilterId := "charge_filter_id"

		flatFilter := &models.FlatFilter{
			OrganizationID:        "org_id",
			BillableMetricCode:    "api_calls",
			PlanID:                "plan_id",
			ChargeID:              "charge_id2",
			ChargeUpdatedAt:       now,
			ChargeFilterID:        &chargeFilterId,
			ChargeFilterUpdatedAt: &now,
			Filters:               &models.FlatFilterValues{"scheme": []string{"visa"}},
		}

		event := models.EnrichedEvent{
			OrganizationID:         "1a901a90-1a90-1a90-1a90-1a901a901a90",
			ExternalSubscriptionID: "sub_id",
			Code:                   "api_calls",
			Properties:             map[string]any{"scheme": "visa"},
			SubscriptionID:         "sub123",
			FlatFilter:             flatFilter,
		}

		cacheService.ExpireCache([]*models.EnrichedEvent{&event})

		assert.Equal(t, 1, cacheStore.ExecutionCount)
	})

	t.Run("With a single event and no flat filter", func(t *testing.T) {
		setupCacheServiceEnv()

		event := models.EnrichedEvent{
			OrganizationID:         "1a901a90-1a90-1a90-1a90-1a901a901a90",
			ExternalSubscriptionID: "sub_id",
			Code:                   "api_calls",
			Properties:             map[string]any{"scheme": "visa"},
			SubscriptionID:         "sub123",
		}

		cacheService.ExpireCache([]*models.EnrichedEvent{&event})

		assert.Equal(t, 0, cacheStore.ExecutionCount)
	})

	t.Run("With a single event and no flat filter and no charge filter", func(t *testing.T) {
		setupCacheServiceEnv()

		now := time.Now()
		chargeFilterId := "charge_filter_id"

		flatFilter := &models.FlatFilter{
			OrganizationID:        "org_id",
			BillableMetricCode:    "api_calls",
			PlanID:                "plan_id",
			ChargeID:              "charge_id2",
			ChargeUpdatedAt:       now,
			ChargeFilterID:        &chargeFilterId,
			ChargeFilterUpdatedAt: &now,
			Filters:               &models.FlatFilterValues{"scheme": []string{"visa"}},
		}

		event := models.EnrichedEvent{
			OrganizationID:         "1a901a90-1a90-1a90-1a90-1a901a901a90",
			ExternalSubscriptionID: "sub_id",
			Code:                   "api_calls",
			Properties:             map[string]any{"scheme": "visa"},
			SubscriptionID:         "sub123",
			FlatFilter:             flatFilter,
		}

		cacheService.ExpireCache([]*models.EnrichedEvent{&event})

		assert.Equal(t, 1, cacheStore.ExecutionCount)
	})

	t.Run("With multiple events", func(t *testing.T) {
		setupCacheServiceEnv()

		now := time.Now()
		chargeFilterId1 := "charge_filter_id1"
		chargeFilterId2 := "charge_filter_id2"

		flatFilter1 := &models.FlatFilter{
			OrganizationID:        "org_id",
			BillableMetricCode:    "api_calls",
			PlanID:                "plan_id",
			ChargeID:              "charge_id2",
			ChargeUpdatedAt:       now,
			ChargeFilterID:        &chargeFilterId1,
			ChargeFilterUpdatedAt: &now,
			Filters:               &models.FlatFilterValues{"scheme": []string{"visa"}},
		}

		flatFilter2 := &models.FlatFilter{
			OrganizationID:        "org_id",
			BillableMetricCode:    "api_calls",
			PlanID:                "plan_id",
			ChargeID:              "charge_id2",
			ChargeUpdatedAt:       now,
			ChargeFilterID:        &chargeFilterId2,
			ChargeFilterUpdatedAt: &now,
			Filters:               &models.FlatFilterValues{"scheme": []string{"visa"}},
		}

		event1 := models.EnrichedEvent{
			OrganizationID:         "1a901a90-1a90-1a90-1a90-1a901a901a90",
			ExternalSubscriptionID: "sub_id",
			Code:                   "api_calls",
			Properties:             map[string]any{"scheme": "visa"},
			SubscriptionID:         "sub123",
			FlatFilter:             flatFilter1,
		}

		event2 := models.EnrichedEvent{
			OrganizationID:         "1a901a90-1a90-1a90-1a90-1a901a901a90",
			ExternalSubscriptionID: "sub_id",
			Code:                   "api_calls",
			Properties:             map[string]any{"scheme": "visa"},
			SubscriptionID:         "sub123",
			FlatFilter:             flatFilter2,
		}

		cacheService.ExpireCache([]*models.EnrichedEvent{&event1, &event2})

		assert.Equal(t, 2, cacheStore.ExecutionCount)
	})

	t.Run("With multiple events and a missing filter", func(t *testing.T) {
		setupCacheServiceEnv()

		now := time.Now()
		chargeFilterId := "charge_filter_id"

		flatFilter := &models.FlatFilter{
			OrganizationID:        "org_id",
			BillableMetricCode:    "api_calls",
			PlanID:                "plan_id",
			ChargeID:              "charge_id2",
			ChargeUpdatedAt:       now,
			ChargeFilterID:        &chargeFilterId,
			ChargeFilterUpdatedAt: &now,
			Filters:               &models.FlatFilterValues{"scheme": []string{"visa"}},
		}

		event1 := models.EnrichedEvent{
			OrganizationID:         "1a901a90-1a90-1a90-1a90-1a901a901a90",
			ExternalSubscriptionID: "sub_id",
			Code:                   "api_calls",
			Properties:             map[string]any{"scheme": "visa"},
			SubscriptionID:         "sub123",
			FlatFilter:             flatFilter,
		}

		event2 := models.EnrichedEvent{
			OrganizationID:         "1a901a90-1a90-1a90-1a90-1a901a901a90",
			ExternalSubscriptionID: "sub_id",
			Code:                   "api_calls",
			Properties:             map[string]any{"scheme": "visa"},
			SubscriptionID:         "sub123",
		}

		cacheService.ExpireCache([]*models.EnrichedEvent{&event1, &event2})

		assert.Equal(t, 1, cacheStore.ExecutionCount)
	})
}
