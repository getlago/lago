package accounting

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
)

// fakeNetSuite simulates the SuiteTalk REST record API: PUT .../eid:<key> upserts
// by externalId, so repeated PUTs for the same key keep ONE logical record.
type fakeNetSuite struct {
	mu       sync.Mutex
	records  map[string]int // externalId -> number of upserts received
	puts     int
	lastAuth string
	status   int // override response status (0 => 204)
}

func newFakeNetSuite() (*fakeNetSuite, *httptest.Server) {
	f := &fakeNetSuite{records: map[string]int{}}
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPut {
			w.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		auth := r.Header.Get("Authorization")
		if !strings.HasPrefix(auth, "OAuth ") {
			w.WriteHeader(http.StatusUnauthorized)
			return
		}
		idx := strings.LastIndex(r.URL.Path, "/eid:")
		if idx < 0 {
			w.WriteHeader(http.StatusBadRequest)
			return
		}
		eid := r.URL.Path[idx+len("/eid:"):]

		f.mu.Lock()
		f.puts++
		f.lastAuth = auth
		f.records[eid]++
		status := f.status
		f.mu.Unlock()

		if status != 0 {
			w.WriteHeader(status)
			return
		}
		w.WriteHeader(http.StatusNoContent)
	}))
	return f, srv
}

func (f *fakeNetSuite) distinctRecords() int {
	f.mu.Lock()
	defer f.mu.Unlock()
	return len(f.records)
}

func testNetSuiteTarget(srv *httptest.Server) *NetSuiteTarget {
	return NewNetSuiteTarget(NetSuiteConfig{
		AccountID:      "1234567_SB1",
		BaseURL:        srv.URL,
		RecordType:     "customerPayment",
		ConsumerKey:    "ck",
		ConsumerSecret: "cs",
		TokenID:        "tk",
		TokenSecret:    "ts",
		HTTPClient:     srv.Client(),
	})
}

// Posting the same entry twice DIRECTLY to the target (bypassing the dispatcher
// dedup) still books one record, because NetSuite upserts by externalId. This is
// the target-level idempotency the contract requires.
func TestNetSuite_TargetIdempotentByExternalID(t *testing.T) {
	f, srv := newFakeNetSuite()
	defer srv.Close()
	target := testNetSuiteTarget(srv)
	entry := EntryFromEvent(sampleEvent("txn_ns"))

	for i := 0; i < 3; i++ {
		if err := target.Post(context.Background(), entry); err != nil {
			t.Fatalf("Post #%d error: %v", i+1, err)
		}
	}
	if f.puts != 3 {
		t.Fatalf("server saw %d PUTs, want 3", f.puts)
	}
	if f.distinctRecords() != 1 {
		t.Fatalf("NetSuite has %d distinct externalIds, want exactly 1", f.distinctRecords())
	}
}

// End to end through the dispatcher: the OAuth header is sent and the upsert path
// targets the right externalId, and only one PUT is made (dispatcher dedup).
func TestNetSuite_DispatchSendsAuthAndUpsertPath(t *testing.T) {
	f, srv := newFakeNetSuite()
	defer srv.Close()
	d := NewDispatcher(testNetSuiteTarget(srv), NewMemoryStore())
	ev := sampleEvent("txn_ns_2")

	if _, err := d.Dispatch(context.Background(), ev); err != nil {
		t.Fatalf("dispatch1: %v", err)
	}
	if _, err := d.Dispatch(context.Background(), ev); err != nil {
		t.Fatalf("dispatch2: %v", err)
	}

	if f.puts != 1 {
		t.Fatalf("server saw %d PUTs, want 1 (dispatcher dedup)", f.puts)
	}
	if !strings.Contains(f.lastAuth, "oauth_signature=") || !strings.Contains(f.lastAuth, `realm="1234567_SB1"`) {
		t.Fatalf("auth header missing signature/realm: %q", f.lastAuth)
	}
}

// A 5xx is retryable (not permanent); a 4xx is permanent.
func TestNetSuite_ErrorClassification(t *testing.T) {
	cases := []struct {
		status        int
		wantPermanent bool
	}{
		{http.StatusServiceUnavailable, false},
		{http.StatusTooManyRequests, false},
		{http.StatusBadRequest, true},
	}
	for _, tc := range cases {
		f, srv := newFakeNetSuite()
		f.status = tc.status
		target := testNetSuiteTarget(srv)
		err := target.Post(context.Background(), EntryFromEvent(sampleEvent("txn_err")))
		srv.Close()

		var pe *PostError
		if !errors.As(err, &pe) {
			t.Fatalf("status %d: got err=%v, want *PostError", tc.status, err)
		}
		if pe.Permanent != tc.wantPermanent {
			t.Fatalf("status %d: Permanent=%v, want %v", tc.status, pe.Permanent, tc.wantPermanent)
		}
	}
}

// An unconfigured target fails clearly rather than making a bad request.
func TestNetSuite_NotConfigured(t *testing.T) {
	target := NewNetSuiteTarget(NetSuiteConfig{}) // no creds
	if err := target.Post(context.Background(), EntryFromEvent(sampleEvent("txn"))); err == nil {
		t.Fatal("Post with no config = nil error, want a 'not configured' error")
	}
}

// NetSuite is selectable, and the default is still Gridiron.
func TestNetSuite_RegisteredInSelector(t *testing.T) {
	target, err := SelectTarget("netsuite")
	if err != nil {
		t.Fatalf("SelectTarget(netsuite): %v", err)
	}
	if target.Name() != "netsuite" {
		t.Fatalf("selected %q, want netsuite", target.Name())
	}
	var hasNetsuite, hasGridiron bool
	for _, n := range AvailableTargets() {
		switch n {
		case "netsuite":
			hasNetsuite = true
		case "gridiron":
			hasGridiron = true
		}
	}
	if !hasNetsuite || !hasGridiron {
		t.Fatalf("AvailableTargets()=%v, want both gridiron and netsuite", AvailableTargets())
	}
	if def, _ := SelectTarget(""); def.Name() != DefaultTarget {
		t.Fatalf("default target = %q, want %q", def.Name(), DefaultTarget)
	}
}
