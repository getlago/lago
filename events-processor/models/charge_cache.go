package models

import (
	"strings"
	"time"

	"github.com/getlago/lago/events-processor/utils"
)

const CACHE_KEY_VERSION = "1"

type ChargeCache struct {
	CacheStore Cacher
}

func NewChargeCache(cacheStore *Cacher) *ChargeCache {
	return &ChargeCache{
		CacheStore: *cacheStore,
	}
}

func (cache *ChargeCache) Expire(ff *FlatFilter, subID string) utils.Result[bool] {
	// Build cache key components
	keyParts := []string{
		"charge-usage",
		CACHE_KEY_VERSION,
		ff.ChargeID,
		subID,
		ff.ChargeUpdatedAt.UTC().Format(time.RFC3339),
	}

	// Add filter-specific parts if filters exist
	if ff.ChargeFilterID != nil && ff.ChargeFilterUpdatedAt != nil {
		keyParts = append(keyParts,
			*ff.ChargeFilterID,
			ff.ChargeFilterUpdatedAt.UTC().Format(time.RFC3339),
		)
	}

	cacheKey := strings.Join(keyParts, "/")

	// Remove the cache entry
	return cache.CacheStore.ExpireKey(cacheKey)
}
