package accounting

import (
	"context"
	"errors"
	"sync"
	"testing"
	"time"
)

func sampleEvent(txID string) UsageEvent {
	return UsageEvent{
		TransactionID:          txID,
		OrganizationID:         "org_1",
		ExternalSubscriptionID: "sub_1",
		Code:                   "api_calls",
		Timestamp:              time.Unix(1700000000, 0).UTC(),
		AmountCents:            1299,
		Currency:               "USD",
	}
}

// The selector must default to the in-house Bigcapital module.
func TestSelectTarget_DefaultsToBigcapital(t *testing.T) {
	if DefaultTarget != "bigcapital" {
		t.Fatalf("DefaultTarget = %q, want bigcapital", DefaultTarget)
	}
	for _, name := range []string{"", "bigcapital"} {
		tgt, err := SelectTarget(name)
		if err != nil {
			t.Fatalf("SelectTarget(%q) error: %v", name, err)
		}
		if tgt.Name() != "bigcapital" {
			t.Fatalf("SelectTarget(%q) = %q, want bigcapital", name, tgt.Name())
		}
	}
}

// An unregistered target errors instead of silently misrouting.
func TestSelectTarget_UnknownErrors(t *testing.T) {
	if _, err := SelectTarget("no-such-erp"); err == nil {
		t.Fatal(`SelectTarget("no-such-erp") = nil error, want error for unregistered target`)
	}
}

// One usage event books exactly one accounting entry.
func TestDispatch_PostsExactlyOneEntry(t *testing.T) {
	g := NewMemoryLedger()
	d := NewDispatcher(g, NewMemoryStore())

	res, err := d.Dispatch(context.Background(), sampleEvent("txn_1"))
	if err != nil {
		t.Fatalf("Dispatch error: %v", err)
	}
	if !res.Posted || res.Deduplicated {
		t.Fatalf("first dispatch = %+v, want Posted=true Deduplicated=false", res)
	}
	if g.Count() != 1 {
		t.Fatalf("ledger has %d entries, want 1", g.Count())
	}
}

// "given usage event X, the target receives entry Y, EXACTLY ONCE" - the same
// event delivered twice books one entry.
func TestDispatch_DuplicateEventBooksOnce(t *testing.T) {
	g := NewMemoryLedger()
	d := NewDispatcher(g, NewMemoryStore())
	ev := sampleEvent("txn_dup")

	if _, err := d.Dispatch(context.Background(), ev); err != nil {
		t.Fatalf("first dispatch error: %v", err)
	}
	res, err := d.Dispatch(context.Background(), ev) // same transaction id
	if err != nil {
		t.Fatalf("second dispatch error: %v", err)
	}
	if res.Posted || !res.Deduplicated {
		t.Fatalf("second dispatch = %+v, want Posted=false Deduplicated=true", res)
	}
	if g.Count() != 1 {
		t.Fatalf("ledger has %d entries after duplicate, want exactly 1", g.Count())
	}
}

// Without a transaction id we refuse rather than risk a double-booking.
func TestDispatch_MissingIdempotencyKey(t *testing.T) {
	g := NewMemoryLedger()
	d := NewDispatcher(g, NewMemoryStore())

	_, err := d.Dispatch(context.Background(), sampleEvent("   "))
	if !errors.Is(err, ErrNoIdempotencyKey) {
		t.Fatalf("Dispatch with blank txn = %v, want ErrNoIdempotencyKey", err)
	}
	if g.Count() != 0 {
		t.Fatalf("ledger has %d entries, want 0 (refused without key)", g.Count())
	}
}

// Exactly-once must hold even under concurrent redelivery of the same event.
func TestDispatch_ConcurrentDuplicatesBookOnce(t *testing.T) {
	g := NewMemoryLedger()
	d := NewDispatcher(g, NewMemoryStore())
	ev := sampleEvent("txn_race")

	const n = 64
	var wg sync.WaitGroup
	wg.Add(n)
	for i := 0; i < n; i++ {
		go func() {
			defer wg.Done()
			_, _ = d.Dispatch(context.Background(), ev)
		}()
	}
	wg.Wait()

	if g.Count() != 1 {
		t.Fatalf("ledger has %d entries after %d concurrent duplicates, want exactly 1", g.Count(), n)
	}
}

// flakyTarget fails its first failFirst Post calls, then delegates to an
// idempotent ledger. Models a transient accounting outage followed by retries.
type flakyTarget struct {
	inner     *MemoryLedger
	mu        sync.Mutex
	calls     int
	failFirst int
}

func (f *flakyTarget) Name() string { return "flaky" }

func (f *flakyTarget) Post(ctx context.Context, e AccountingEntry) error {
	f.mu.Lock()
	f.calls++
	fail := f.calls <= f.failFirst
	f.mu.Unlock()
	if fail {
		return errors.New("transient accounting outage")
	}
	return f.inner.Post(ctx, e)
}

// A transient failure leaves nothing delivered; the retry books exactly once.
func TestDispatch_RetryAfterFailureBooksOnce(t *testing.T) {
	ledger := NewMemoryLedger()
	target := &flakyTarget{inner: ledger, failFirst: 1}
	d := NewDispatcher(target, NewMemoryStore())
	ev := sampleEvent("txn_retry")

	if _, err := d.Dispatch(context.Background(), ev); err == nil {
		t.Fatal("first dispatch = nil error, want transient failure")
	}
	if ledger.Count() != 0 {
		t.Fatalf("ledger has %d entries after failed attempt, want 0", ledger.Count())
	}

	res, err := d.Dispatch(context.Background(), ev) // retry
	if err != nil {
		t.Fatalf("retry dispatch error: %v", err)
	}
	if !res.Posted {
		t.Fatalf("retry = %+v, want Posted=true", res)
	}
	if ledger.Count() != 1 {
		t.Fatalf("ledger has %d entries after retry, want exactly 1", ledger.Count())
	}
}
