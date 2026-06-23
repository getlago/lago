package accounting

import (
	"context"
	"fmt"
	"sort"
	"sync"
)

// DefaultTarget is selected when no target is specified. Product decision: the
// outbound accounting selector defaults to the in-house Bigcapital module FIRST;
// QuickBooks, Xero and NetSuite are opt-in alternatives a user can switch to.
// Each target registers itself from its own file's init().
const DefaultTarget = "bigcapital"

var (
	registryMu sync.RWMutex
	registry   = map[string]func() AccountingTarget{}
)

// Register makes a target available for selection by name.
func Register(name string, factory func() AccountingTarget) {
	registryMu.Lock()
	defer registryMu.Unlock()
	registry[name] = factory
}

// SelectTarget returns the target for name. An empty name selects DefaultTarget
// (Bigcapital). Unknown names error rather than silently falling back, so a typo
// in the ERP selector can never misroute revenue to the wrong place.
func SelectTarget(name string) (AccountingTarget, error) {
	if name == "" {
		name = DefaultTarget
	}
	registryMu.RLock()
	factory, ok := registry[name]
	registryMu.RUnlock()
	if !ok {
		return nil, fmt.Errorf("accounting: target %q is not registered (available: %v)", name, AvailableTargets())
	}
	return factory(), nil
}

// AvailableTargets lists registered target names, sorted. The Gridiron ERP UI
// renders these as the selector's options (with DefaultTarget shown first).
func AvailableTargets() []string {
	registryMu.RLock()
	defer registryMu.RUnlock()
	names := make([]string, 0, len(registry))
	for n := range registry {
		names = append(names, n)
	}
	sort.Strings(names)
	return names
}

// MemoryLedger is an in-memory, idempotent AccountingTarget used as a reference
// and in tests/dry-runs: it books entries and dedupes by IdempotencyKey so you
// can assert exactly-once. It is intentionally NOT registered in the selector;
// production routes to one of the real ERP targets.
type MemoryLedger struct {
	mu      sync.Mutex
	name    string
	entries map[string]AccountingEntry
}

// NewMemoryLedger returns an empty in-memory ledger.
func NewMemoryLedger() *MemoryLedger {
	return &MemoryLedger{name: "memory", entries: make(map[string]AccountingEntry)}
}

// Name identifies the target.
func (m *MemoryLedger) Name() string { return m.name }

// Post books an entry idempotently on its IdempotencyKey.
func (m *MemoryLedger) Post(_ context.Context, entry AccountingEntry) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if _, exists := m.entries[entry.IdempotencyKey]; exists {
		return nil // already booked; idempotent no-op
	}
	m.entries[entry.IdempotencyKey] = entry
	return nil
}

// Count returns the number of distinct booked entries (for assertions/metrics).
func (m *MemoryLedger) Count() int {
	m.mu.Lock()
	defer m.mu.Unlock()
	return len(m.entries)
}
