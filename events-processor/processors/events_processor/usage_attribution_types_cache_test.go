package events_processor

import (
	"testing"
	"time"

	"github.com/stretchr/testify/assert"

	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/utils"
)

func TestUsageAttributionTypesCache(t *testing.T) {
	types := []*models.UsageAttributionType{{Code: "user", AttributionKeys: utils.StringArray{"user_id"}}}

	t.Run("returns the types of the organization until they expire", func(t *testing.T) {
		var cache usageAttributionTypesCache
		cache.set("org-1", types)

		cached, ok := cache.get("org-1")
		assert.True(t, ok)
		assert.Equal(t, types, cached)

		cache.entries["org-1"] = usageAttributionTypesEntry{types: types, expiresAt: time.Now().Add(-time.Second)}

		_, ok = cache.get("org-1")
		assert.False(t, ok)
	})

	t.Run("keeps an organization without types", func(t *testing.T) {
		var cache usageAttributionTypesCache
		cache.set("org-1", []*models.UsageAttributionType{})

		cached, ok := cache.get("org-1")
		assert.True(t, ok)
		assert.Empty(t, cached)
	})

	t.Run("misses an organization not fetched yet", func(t *testing.T) {
		var cache usageAttributionTypesCache
		cache.set("org-1", types)

		_, ok := cache.get("org-2")
		assert.False(t, ok)
	})
}
