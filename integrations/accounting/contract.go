// Package accounting defines the contract for delivering Lago usage/billing
// events to an accounting target (the customer's books) with an EXACTLY-ONCE
// guarantee.
//
// This package is the reference implementation AND the executable contract for
// the future "Lago -> accounting" connector. The real connector will implement
// AccountingTarget for the selected ERP/accounting system; these same contract
// tests (contract_test.go, run by repo-gates/accounting-contract.sh) must keep
// passing. That is what protects billing-vs-books integrity.
//
// Exactly-once is achieved the only way it reliably can be:
//   - every entry carries an idempotency key (the Lago transaction_id), and
//   - every target is idempotent on that key.
//
// Dispatch may be retried, redelivered, or called concurrently any number of
// times; the target still ends with exactly one entry per transaction id.
package accounting

import (
	"context"
	"errors"
	"strings"
	"time"
)

// ErrNoIdempotencyKey is returned when an event has no transaction id. Without a
// stable key we cannot promise exactly-once, so we refuse rather than risk
// double-booking revenue.
var ErrNoIdempotencyKey = errors.New("accounting: usage event has no transaction_id (idempotency key)")

// UsageEvent mirrors the fields Lago ingests (see connectors/http.yml).
type UsageEvent struct {
	TransactionID          string
	OrganizationID         string
	ExternalSubscriptionID string
	Code                   string
	Timestamp              time.Time
	AmountCents            int64
	Currency               string
}

// AccountingEntry is the booked record derived from a usage event. Every target
// must dedupe on IdempotencyKey.
type AccountingEntry struct {
	IdempotencyKey         string
	OrganizationID         string
	ExternalSubscriptionID string
	Code                   string
	AmountCents            int64
	Currency               string
	OccurredAt             time.Time
}

// EntryFromEvent builds the accounting entry for a usage event.
func EntryFromEvent(ev UsageEvent) AccountingEntry {
	return AccountingEntry{
		IdempotencyKey:         strings.TrimSpace(ev.TransactionID),
		OrganizationID:         ev.OrganizationID,
		ExternalSubscriptionID: ev.ExternalSubscriptionID,
		Code:                   ev.Code,
		AmountCents:            ev.AmountCents,
		Currency:               ev.Currency,
		OccurredAt:             ev.Timestamp,
	}
}

// AccountingTarget is a destination for booked entries: the in-house Gridiron
// module by default, or an external ERP.
//
// CONTRACT: implementations MUST be idempotent on AccountingEntry.IdempotencyKey.
// Posting the same key more than once books it exactly once.
type AccountingTarget interface {
	Name() string
	Post(ctx context.Context, entry AccountingEntry) error
}

// IdempotencyStore remembers which keys have already been delivered so we can
// skip redundant posts. The in-memory implementation here is the reference; a
// real deployment backs this with Postgres/Redis.
type IdempotencyStore interface {
	Seen(key string) bool
	Record(key string)
}

// DispatchResult reports what Dispatch did with one event.
type DispatchResult struct {
	Target       string
	Posted       bool // a new entry was delivered to the target
	Deduplicated bool // the key was already delivered; this call was a no-op
}

// Dispatcher books usage events to a target exactly once.
type Dispatcher struct {
	target AccountingTarget
	store  IdempotencyStore
}

// NewDispatcher wires a target and an idempotency store.
func NewDispatcher(target AccountingTarget, store IdempotencyStore) *Dispatcher {
	return &Dispatcher{target: target, store: store}
}

// Dispatch books one usage event. It is safe to call repeatedly for the same
// event (retries, redeliveries, concurrent calls): the target ends with exactly
// one entry per transaction id.
func (d *Dispatcher) Dispatch(ctx context.Context, ev UsageEvent) (DispatchResult, error) {
	key := strings.TrimSpace(ev.TransactionID)
	res := DispatchResult{Target: d.target.Name()}
	if key == "" {
		return res, ErrNoIdempotencyKey
	}

	// Fast path: already delivered -> no-op (exactly-once).
	if d.store.Seen(key) {
		res.Deduplicated = true
		return res, nil
	}

	// Deliver. The target is idempotent on the key, so even if a concurrent
	// caller delivers the same key first, no double-booking occurs.
	if err := d.target.Post(ctx, EntryFromEvent(ev)); err != nil {
		// Do NOT record on failure: a later retry must be able to deliver.
		return res, err
	}

	d.store.Record(key)
	res.Posted = true
	return res, nil
}
