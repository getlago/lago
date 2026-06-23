package accounting

import (
	"context"
	"sync"
)

// MemoryStore is a thread-safe, in-memory IdempotencyStore. Reference only; a
// production deployment uses a durable store (RedisStore, or a Postgres-backed
// store) so dedup survives restarts.
type MemoryStore struct {
	mu   sync.Mutex
	seen map[string]struct{}
}

// NewMemoryStore returns an empty MemoryStore.
func NewMemoryStore() *MemoryStore {
	return &MemoryStore{seen: make(map[string]struct{})}
}

// Seen reports whether key was already recorded. It never errors.
func (m *MemoryStore) Seen(_ context.Context, key string) (bool, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	_, ok := m.seen[key]
	return ok, nil
}

// Record marks key as delivered. Recording the same key twice is a no-op.
func (m *MemoryStore) Record(_ context.Context, key string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.seen[key] = struct{}{}
	return nil
}
