package mcp

import (
	"net/http"
	"net/http/httptest"
	"sync"
	"testing"
)

// End to end through the MCP server: read tools dispatch to Lago and ONLY ever
// issue GET requests. This is the gate that proves the agent can't mutate.
func TestReadOnlyTools_DispatchAndStayGET(t *testing.T) {
	var mu sync.Mutex
	var methods []string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		mu.Lock()
		methods = append(methods, r.Method)
		mu.Unlock()
		_, _ = w.Write([]byte(`{"customer":{"external_id":"cust_1"}}`))
	}))
	defer srv.Close()
	s := NewServer("lago", "0.1.0", ReadOnlyTools(NewLagoClient(srv.URL, "k", srv.Client())))

	resps := runRPC(t, s,
		`{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"lago_get_customer","arguments":{"external_id":"cust_1"}}}`,
		`{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"lago_list_invoices","arguments":{"external_customer_id":"cust_1"}}}`,
		`{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"lago_list_wallets","arguments":{"external_customer_id":"cust_1"}}}`,
	)
	for _, r := range resps {
		res, _ := r["result"].(map[string]any)
		if res["isError"] == true {
			t.Fatalf("tool call returned error: %v", res)
		}
	}
	mu.Lock()
	defer mu.Unlock()
	if len(methods) != 3 {
		t.Fatalf("upstream saw %d requests, want 3", len(methods))
	}
	for _, m := range methods {
		if m != http.MethodGet {
			t.Fatalf("tool issued %s, want GET only (read-only invariant)", m)
		}
	}
}

// All six read tools are advertised.
func TestReadOnlyTools_AllRegistered(t *testing.T) {
	s := NewServer("lago", "0.1.0", ReadOnlyTools(NewLagoClient("http://unused", "k", nil)))
	resps := runRPC(t, s, `{"jsonrpc":"2.0","id":1,"method":"tools/list"}`)
	tl, _ := resps[0]["result"].(map[string]any)
	tools, _ := tl["tools"].([]any)
	want := map[string]bool{
		"lago_get_customer": true, "lago_customer_current_usage": true,
		"lago_list_invoices": true, "lago_get_invoice": true,
		"lago_list_subscriptions": true, "lago_list_wallets": true,
	}
	for _, tool := range tools {
		m, _ := tool.(map[string]any)
		delete(want, m["name"].(string))
	}
	if len(want) != 0 {
		t.Fatalf("missing tools: %v", want)
	}
}

// A required argument that's missing fails the tool clearly (no upstream call).
func TestReadOnlyTools_MissingRequiredArg(t *testing.T) {
	var called bool
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		called = true
		_, _ = w.Write([]byte(`{}`))
	}))
	defer srv.Close()
	s := NewServer("lago", "0.1.0", ReadOnlyTools(NewLagoClient(srv.URL, "k", srv.Client())))
	resps := runRPC(t, s,
		`{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"lago_get_customer","arguments":{}}}`,
	)
	res, _ := resps[0]["result"].(map[string]any)
	if res["isError"] != true {
		t.Fatalf("missing arg should be isError; got %v", resps[0])
	}
	if called {
		t.Fatal("upstream should not be called when a required arg is missing")
	}
}
