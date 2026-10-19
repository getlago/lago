package events_processor

import (
	"sync"
	"time"

	"github.com/getlago/lago/events-processor/models"
)

// usageAttributionTypesTTL is also how long a change to the types takes to apply to the events.
const usageAttributionTypesTTL = 10 * time.Second

// usageAttributionTypesCache keeps the usage attribution types of each organization for a few seconds,
// so that its events do not all query them. Its zero value is ready to use.
type usageAttributionTypesCache struct {
	mu      sync.Mutex
	entries map[string]usageAttributionTypesEntry
}

type usageAttributionTypesEntry struct {
	types     []*models.UsageAttributionType
	expiresAt time.Time
}

func (c *usageAttributionTypesCache) get(organizationID string) ([]*models.UsageAttributionType, bool) {
	c.mu.Lock()
	defer c.mu.Unlock()

	entry, ok := c.entries[organizationID]
	if !ok || time.Now().After(entry.expiresAt) {
		return nil, false
	}

	return entry.types, true
}

func (c *usageAttributionTypesCache) set(organizationID string, types []*models.UsageAttributionType) {
	c.mu.Lock()
	defer c.mu.Unlock()

	if c.entries == nil {
		c.entries = make(map[string]usageAttributionTypesEntry)
	}

	c.entries[organizationID] = usageAttributionTypesEntry{
		types:     types,
		expiresAt: time.Now().Add(usageAttributionTypesTTL),
	}
}
