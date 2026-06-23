package mcp

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
)

// The read-only invariant: every typed method issues a GET with Bearer auth.
func TestLagoClient_IsGetOnlyAndAuthenticated(t *testing.T) {
	var mu sync.Mutex
	var methods, paths []string
	var lastAuth string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		mu.Lock()
		methods = append(methods, r.Method)
		paths = append(paths, r.URL.Path)
		lastAuth = r.Header.Get("Authorization")
		mu.Unlock()
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"ok":true}`))
	}))
	defer srv.Close()
	c := NewLagoClient(srv.URL, "secret-key", srv.Client())

	ctx := context.Background()
	_, _ = c.GetCustomer(ctx, "cust_1")
	_, _ = c.CurrentUsage(ctx, "cust_1", "sub_1")
	_, _ = c.ListInvoices(ctx, "cust_1")
	_, _ = c.GetInvoice(ctx, "inv_1")
	_, _ = c.ListSubscriptions(ctx, "cust_1")
	_, _ = c.ListWallets(ctx, "cust_1")

	mu.Lock()
	defer mu.Unlock()
	if len(methods) != 6 {
		t.Fatalf("made %d requests, want 6", len(methods))
	}
	for i, m := range methods {
		if m != http.MethodGet {
			t.Fatalf("request %d to %s used %s, want GET (read-only invariant)", i, paths[i], m)
		}
	}
	if lastAuth != "Bearer secret-key" {
		t.Fatalf("Authorization = %q, want 'Bearer secret-key'", lastAuth)
	}
	for _, p := range paths {
		if !strings.HasPrefix(p, "/api/v1/") {
			t.Fatalf("unexpected path %q", p)
		}
	}
}

func TestLagoClient_NotConfigured(t *testing.T) {
	c := NewLagoClient("", "", nil)
	if _, err := c.GetCustomer(context.Background(), "x"); err == nil {
		t.Fatal("expected 'not configured' error with empty URL/key")
	}
}

func TestLagoClient_ErrorsOnNon2xx(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusNotFound)
		_, _ = w.Write([]byte(`{"error":"not found"}`))
	}))
	defer srv.Close()
	c := NewLagoClient(srv.URL, "k", srv.Client())
	if _, err := c.GetCustomer(context.Background(), "missing"); err == nil {
		t.Fatal("expected error on HTTP 404")
	}
}
