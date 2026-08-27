package events_processor

import (
	"context"

	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/utils"
)

type CacheService struct {
	chargeCacheStore *models.ChargeCache
}

func NewCacheService(chargeCacheStore *models.ChargeCache) *CacheService {
	return &CacheService{
		chargeCacheStore: chargeCacheStore,
	}
}

func (s *CacheService) ExpireCache(ctx context.Context, events []*models.EnrichedEvent) {
	for _, event := range events {
		if event.FlatFilter == nil {
			continue
		}

		cacheResult := s.chargeCacheStore.Expire(ctx, event.FlatFilter, event.SubscriptionID)
		if cacheResult.Failure() {
			utils.CaptureError(cacheResult.Error())
		}
	}
}
