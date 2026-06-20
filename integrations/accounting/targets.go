package accounting

import (
	"context"
	"fmt"
	"sort"
	"sync"
)

// DefaultTarget is selected when no target is specified. Product decision: the
// outbound accounting selector in the Gridiron ERP defaults to the in-house
// Gridiron module FIRST; external ERPs (NetSuite, QuickBooks, Xero, SAP, ...)
// are opt-in secondary targets a user can switch to.
const DefaultTarget = "gridiron"

var (
	registryMu sync.RWMutex
	registry   = map[string]func() AccountingTarget{}
)

// Register makes a target available for selection by name. External ERP adapters
// call this from their init() once implemented.
func Register(name string, factory func() AccountingTarget) {
	registryMu.Lock()
	defer registryMu.Unlock()
	registry[name] = factory
}

// SelectTarget returns the target for name. An empty name selects DefaultTarget
// (Gridiron). Unknown names error rather than silently falling back, so a typo
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
// can render this as the selector's options (default first).
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

func init() {
	// The default in-house target is always available.
	Register(DefaultTarget, func() AccountingTarget { return NewGridironAccounting() })
	// External ERP adapters register themselves here when built, e.g.:
	//   Register("netsuite", func() AccountingTarget { return NewNetSuite(cfg) })
	//   Register("quickbooks", func() AccountingTarget { return NewQuickBooks(cfg) })
}

// GridironAccounting is the in-house default target. It is idempotent on the
// entry idempotency key: posting the same key twice books it once. This is a
// reference in-memory ledger; the real module persists entries to the ERP.
type GridironAccounting struct {
	mu      sync.Mutex
	entries map[string]AccountingEntry
}

// NewGridironAccounting returns an empty ledger.
func NewGridironAccounting() *GridironAccounting {
	return &GridironAccounting{entries: make(map[string]AccountingEntry)}
}

// Name identifies the target.
func (g *GridironAccounting) Name() string { return DefaultTarget }

// Post books an entry idempotently on its IdempotencyKey.
func (g *GridironAccounting) Post(_ context.Context, entry AccountingEntry) error {
	g.mu.Lock()
	defer g.mu.Unlock()
	if _, exists := g.entries[entry.IdempotencyKey]; exists {
		return nil // already booked; idempotent no-op
	}
	g.entries[entry.IdempotencyKey] = entry
	return nil
}

// Count returns the number of distinct booked entries (for assertions/metrics).
func (g *GridironAccounting) Count() int {
	g.mu.Lock()
	defer g.mu.Unlock()
	return len(g.entries)
}
