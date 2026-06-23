package accounting

import (
	"context"
	"errors"
	"sync"
	"testing"
	"time"
)

// fakeRedis is an in-memory RedisCmdable that faithfully emulates SetNX/Exists,
// including atomicity, so we can validate RedisStore offline. failExists /
// failSetNX simulate an unreachable Redis.
type fakeRedis struct {
	mu         sync.Mutex
	keys       map[string]time.Time // key -> expiry
	failExists bool
	failSetNX  bool
}

func newFakeRedis() *fakeRedis { return &fakeRedis{keys: map[string]time.Time{}} }

func (f *fakeRedis) SetNX(_ context.Context, key string, ttl time.Duration) (bool, error) {
	if f.failSetNX {
		return false, errors.New("redis unreachable")
	}
	f.mu.Lock()
	defer f.mu.Unlock()
	if _, ok := f.keys[key]; ok {
		return false, nil
	}
	f.keys[key] = time.Now().Add(ttl)
	return true, nil
}

func (f *fakeRedis) Exists(_ context.Context, key string) (bool, error) {
	if f.failExists {
		return false, errors.New("redis unreachable")
	}
	f.mu.Lock()
	defer f.mu.Unlock()
	_, ok := f.keys[key]
	return ok, nil
}

// With a durable RedisStore swapped in for MemoryStore, exactly-once still holds.
func TestRedisStore_DispatchExactlyOnce(t *testing.T) {
	ledger := NewMemoryLedger()
	d := NewDispatcher(ledger, NewRedisStore(newFakeRedis(), "", 0))
	ev := sampleEvent("txn_redis")

	first, err := d.Dispatch(context.Background(), ev)
	if err != nil || !first.Posted {
		t.Fatalf("first dispatch = %+v err=%v, want Posted", first, err)
	}
	second, err := d.Dispatch(context.Background(), ev)
	if err != nil || !second.Deduplicated {
		t.Fatalf("second dispatch = %+v err=%v, want Deduplicated", second, err)
	}
	if ledger.Count() != 1 {
		t.Fatalf("ledger has %d entries, want exactly 1", ledger.Count())
	}
}

func TestRedisStore_ConcurrentExactlyOnce(t *testing.T) {
	ledger := NewMemoryLedger()
	d := NewDispatcher(ledger, NewRedisStore(newFakeRedis(), "", time.Hour))
	ev := sampleEvent("txn_redis_race")

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

	if ledger.Count() != 1 {
		t.Fatalf("ledger has %d entries after %d concurrent dispatches, want 1", ledger.Count(), n)
	}
}

// If the store can't be reached, we must NOT deliver (unknown state).
func TestRedisStore_SeenErrorPreventsDelivery(t *testing.T) {
	ledger := NewMemoryLedger()
	fr := newFakeRedis()
	fr.failExists = true
	d := NewDispatcher(ledger, NewRedisStore(fr, "", 0))

	if _, err := d.Dispatch(context.Background(), sampleEvent("txn_x")); err == nil {
		t.Fatal("dispatch with unreachable store = nil error, want error")
	}
	if ledger.Count() != 0 {
		t.Fatalf("ledger has %d entries, want 0 (must not deliver on unknown state)", ledger.Count())
	}
}

// If recording fails AFTER a successful delivery, the entry is still booked once
// and the error is surfaced (a retry is safe because the target is idempotent).
func TestRedisStore_RecordErrorAfterDeliverySurfaces(t *testing.T) {
	ledger := NewMemoryLedger()
	fr := newFakeRedis()
	fr.failSetNX = true
	d := NewDispatcher(ledger, NewRedisStore(fr, "", 0))

	_, err := d.Dispatch(context.Background(), sampleEvent("txn_rec"))
	if err == nil {
		t.Fatal("dispatch with failing record = nil error, want surfaced error")
	}
	if ledger.Count() != 1 {
		t.Fatalf("ledger has %d entries, want 1 (delivery happened before record failed)", ledger.Count())
	}
}
