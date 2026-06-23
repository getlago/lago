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

// simUpstream is a configurable fake accounting API. It extracts a per-target
// idempotency key from each request and dedupes by it (returning 409 on a
// duplicate, which the shared client treats as "already booked"). It also checks
// that auth headers are present, all under a lock so the race detector is happy.
type simUpstream struct {
	mu           sync.Mutex
	seen         map[string]int
	requests     int
	authFailures int
	forceStatus  int
	extract      func(*http.Request) string
	authOK       func(*http.Request) bool
}

func newSim(extract func(*http.Request) string, authOK func(*http.Request) bool) (*simUpstream, *httptest.Server) {
	s := &simUpstream{seen: map[string]int{}, extract: extract, authOK: authOK}
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		key := s.extract(r)
		ok := s.authOK(r)
		s.mu.Lock()
		s.requests++
		if !ok {
			s.authFailures++
		}
		first := s.seen[key] == 0
		s.seen[key]++
		status := s.forceStatus
		s.mu.Unlock()

		if status != 0 {
			w.WriteHeader(status)
			return
		}
		if first {
			w.WriteHeader(http.StatusOK)
		} else {
			w.WriteHeader(http.StatusConflict) // duplicate key -> idempotent no-op
		}
		_, _ = w.Write([]byte(`{"ok":true}`))
	}))
	return s, srv
}

func (s *simUpstream) distinct() int {
	s.mu.Lock()
	defer s.mu.Unlock()
	return len(s.seen)
}

// httpTargetCase describes how to build a target and how its idempotency key and
// auth appear on the wire.
type httpTargetCase struct {
	name         string
	configured   func(baseURL string, c *http.Client) AccountingTarget
	unconfigured func() AccountingTarget
	extractKey   func(*http.Request) string
	authOK       func(*http.Request) bool
}

func httpTargetCases() []httpTargetCase {
	return []httpTargetCase{
		{
			name: "bigcapital",
			configured: func(u string, c *http.Client) AccountingTarget {
				return NewBigcapitalTarget(BigcapitalConfig{BaseURL: u, AccessToken: "tok", OrganizationID: "org1", HTTPClient: c})
			},
			unconfigured: func() AccountingTarget { return NewBigcapitalTarget(BigcapitalConfig{}) },
			extractKey:   func(r *http.Request) string { return r.Header.Get("Idempotency-Key") },
			authOK: func(r *http.Request) bool {
				return r.Header.Get("x-access-token") == "tok" && r.Header.Get("organization-id") == "org1"
			},
		},
		{
			name: "quickbooks",
			configured: func(u string, c *http.Client) AccountingTarget {
				return NewQuickBooksTarget(QuickBooksConfig{BaseURL: u, RealmID: "realm1", AccessToken: "bear", HTTPClient: c})
			},
			unconfigured: func() AccountingTarget { return NewQuickBooksTarget(QuickBooksConfig{}) },
			extractKey:   func(r *http.Request) string { return r.URL.Query().Get("requestid") },
			authOK:       func(r *http.Request) bool { return r.Header.Get("Authorization") == "Bearer bear" },
		},
		{
			name: "xero",
			configured: func(u string, c *http.Client) AccountingTarget {
				return NewXeroTarget(XeroConfig{BaseURL: u, TenantID: "tenant1", AccessToken: "bear", HTTPClient: c})
			},
			unconfigured: func() AccountingTarget { return NewXeroTarget(XeroConfig{}) },
			extractKey:   func(r *http.Request) string { return r.Header.Get("Idempotency-Key") },
			authOK: func(r *http.Request) bool {
				return r.Header.Get("Authorization") == "Bearer bear" && r.Header.Get("Xero-Tenant-Id") == "tenant1"
			},
		},
		{
			name: "netsuite",
			configured: func(u string, c *http.Client) AccountingTarget {
				return NewNetSuiteTarget(NetSuiteConfig{
					AccountID: "1234567_SB1", BaseURL: u, ConsumerKey: "ck", ConsumerSecret: "cs",
					TokenID: "tk", TokenSecret: "ts", HTTPClient: c,
				})
			},
			unconfigured: func() AccountingTarget { return NewNetSuiteTarget(NetSuiteConfig{}) },
			extractKey: func(r *http.Request) string {
				if i := strings.LastIndex(r.URL.Path, "/eid:"); i >= 0 {
					return r.URL.Path[i+len("/eid:"):]
				}
				return ""
			},
			authOK: func(r *http.Request) bool { return strings.HasPrefix(r.Header.Get("Authorization"), "OAuth ") },
		},
	}
}

// Each target sends a STABLE idempotency token derived from the transaction id,
// so posting the same entry 3x books exactly one record, with valid auth.
func TestHTTPTargets_IdempotentByKeyAndAuthenticated(t *testing.T) {
	for _, tc := range httpTargetCases() {
		t.Run(tc.name, func(t *testing.T) {
			sim, srv := newSim(tc.extractKey, tc.authOK)
			defer srv.Close()
			target := tc.configured(srv.URL, srv.Client())
			if target.Name() != tc.name {
				t.Fatalf("Name() = %q, want %q", target.Name(), tc.name)
			}

			entry := EntryFromEvent(sampleEvent("txn_" + tc.name))
			for i := 0; i < 3; i++ {
				if err := target.Post(context.Background(), entry); err != nil {
					t.Fatalf("Post #%d: %v", i+1, err)
				}
			}
			if sim.requests != 3 {
				t.Fatalf("server saw %d requests, want 3", sim.requests)
			}
			if d := sim.distinct(); d != 1 {
				t.Fatalf("server saw %d distinct idempotency keys, want exactly 1", d)
			}
			if sim.authFailures != 0 {
				t.Fatalf("%d requests had missing/invalid auth", sim.authFailures)
			}
		})
	}
}

// A missing-config target fails clearly instead of firing a bad request.
func TestHTTPTargets_NotConfigured(t *testing.T) {
	for _, tc := range httpTargetCases() {
		t.Run(tc.name, func(t *testing.T) {
			err := tc.unconfigured().Post(context.Background(), EntryFromEvent(sampleEvent("txn")))
			if err == nil {
				t.Fatalf("%s: Post with empty config = nil error, want 'not configured'", tc.name)
			}
		})
	}
}

// Response classification (shared by all targets): 5xx/429 retryable, 4xx permanent.
func TestHTTPTargets_ErrorClassification(t *testing.T) {
	cases := []struct {
		status        int
		wantPermanent bool
	}{
		{http.StatusServiceUnavailable, false},
		{http.StatusTooManyRequests, false},
		{http.StatusBadRequest, true},
	}
	tc := httpTargetCases()[0] // bigcapital exercises the shared doJSONRequest path
	for _, c := range cases {
		sim, srv := newSim(tc.extractKey, tc.authOK)
		sim.forceStatus = c.status
		err := tc.configured(srv.URL, srv.Client()).Post(context.Background(), EntryFromEvent(sampleEvent("txn_e")))
		srv.Close()

		var pe *PostError
		if !errors.As(err, &pe) {
			t.Fatalf("status %d: err=%v, want *PostError", c.status, err)
		}
		if pe.Permanent != c.wantPermanent {
			t.Fatalf("status %d: Permanent=%v, want %v", c.status, pe.Permanent, c.wantPermanent)
		}
	}
}

// All four ERPs are selectable and the default is Bigcapital.
func TestHTTPTargets_RegisteredAndDefault(t *testing.T) {
	want := map[string]bool{"bigcapital": true, "quickbooks": true, "xero": true, "netsuite": true}
	for _, n := range AvailableTargets() {
		delete(want, n)
		tgt, err := SelectTarget(n)
		if err != nil {
			t.Fatalf("SelectTarget(%q): %v", n, err)
		}
		if tgt.Name() != n {
			t.Fatalf("SelectTarget(%q).Name() = %q", n, tgt.Name())
		}
	}
	if len(want) != 0 {
		t.Fatalf("targets not registered: %v", want)
	}
	def, _ := SelectTarget("")
	if def.Name() != "bigcapital" {
		t.Fatalf("default target = %q, want bigcapital", def.Name())
	}
}
