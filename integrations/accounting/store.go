package accounting

import "sync"

// MemoryStore is a thread-safe, in-memory IdempotencyStore. Reference only; a
// production deployment backs idempotency with a durable store (Postgres/Redis)
// so it survives restarts.
type MemoryStore struct {
	mu   sync.Mutex
	seen map[string]struct{}
}

// NewMemoryStore returns an empty MemoryStore.
func NewMemoryStore() *MemoryStore {
	return &MemoryStore{seen: make(map[string]struct{})}
}

// Seen reports whether key was already recorded.
func (m *MemoryStore) Seen(key string) bool {
	m.mu.Lock()
	defer m.mu.Unlock()
	_, ok := m.seen[key]
	return ok
}

// Record marks key as delivered. Recording the same key twice is a no-op.
func (m *MemoryStore) Record(key string) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.seen[key] = struct{}{}
}
