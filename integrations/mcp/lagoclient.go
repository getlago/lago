// Package mcp is a READ-ONLY Model Context Protocol server that exposes the Lago
// billing API as agent tools, so an AI agent can answer billing/ERP questions
// without being able to change anything.
//
// The read-only guarantee is structural: LagoClient has no method that mutates,
// and its single request path hard-codes HTTP GET. Even a buggy or adversarial
// tool call can therefore only ever read. The MCP gate
// (repo-gates/mcp-gate.sh) asserts this with a test that fails if any upstream
// request is not a GET.
package mcp

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"
)

// LagoClient is a read-only client for the Lago REST API.
type LagoClient struct {
	baseURL string
	apiKey  string
	http    *http.Client
}

// NewLagoClient builds a client. baseURL is e.g. https://billing.example.com and
// apiKey is a Lago API key (Bearer token). A nil http.Client gets a 15s default.
func NewLagoClient(baseURL, apiKey string, hc *http.Client) *LagoClient {
	if hc == nil {
		hc = &http.Client{Timeout: 15 * time.Second}
	}
	return &LagoClient{baseURL: strings.TrimRight(baseURL, "/"), apiKey: apiKey, http: hc}
}

// get performs a GET — and ONLY ever a GET — against the Lago API. This is the
// single choke point through which every tool reaches Lago, which is what makes
// the whole server read-only by construction.
func (c *LagoClient) get(ctx context.Context, path string, query url.Values) (json.RawMessage, error) {
	if c.baseURL == "" || c.apiKey == "" {
		return nil, fmt.Errorf("lago client not configured (set LAGO_API_URL and LAGO_API_KEY)")
	}
	endpoint := c.baseURL + path
	if len(query) > 0 {
		endpoint += "?" + query.Encode()
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil) // GET only
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+c.apiKey)
	req.Header.Set("Accept", "application/json")

	resp, err := c.http.Do(req)
	if err != nil {
		return nil, fmt.Errorf("lago request: %w", err)
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, fmt.Errorf("lago GET %s -> HTTP %d: %s", path, resp.StatusCode, truncate(string(body), 300))
	}
	return json.RawMessage(body), nil
}

// GetCustomer fetches a customer by external_id.
func (c *LagoClient) GetCustomer(ctx context.Context, externalID string) (json.RawMessage, error) {
	return c.get(ctx, "/api/v1/customers/"+url.PathEscape(externalID), nil)
}

// CurrentUsage returns the current (uninvoiced) usage for a subscription.
func (c *LagoClient) CurrentUsage(ctx context.Context, externalCustomerID, externalSubscriptionID string) (json.RawMessage, error) {
	q := url.Values{}
	q.Set("external_subscription_id", externalSubscriptionID)
	return c.get(ctx, "/api/v1/customers/"+url.PathEscape(externalCustomerID)+"/current_usage", q)
}

// ListInvoices lists invoices, optionally filtered to one customer.
func (c *LagoClient) ListInvoices(ctx context.Context, externalCustomerID string) (json.RawMessage, error) {
	q := url.Values{}
	if externalCustomerID != "" {
		q.Set("external_customer_id", externalCustomerID)
	}
	return c.get(ctx, "/api/v1/invoices", q)
}

// GetInvoice fetches a single invoice by its lago_id.
func (c *LagoClient) GetInvoice(ctx context.Context, lagoID string) (json.RawMessage, error) {
	return c.get(ctx, "/api/v1/invoices/"+url.PathEscape(lagoID), nil)
}

// ListSubscriptions lists subscriptions, optionally filtered to one customer.
func (c *LagoClient) ListSubscriptions(ctx context.Context, externalCustomerID string) (json.RawMessage, error) {
	q := url.Values{}
	if externalCustomerID != "" {
		q.Set("external_customer_id", externalCustomerID)
	}
	return c.get(ctx, "/api/v1/subscriptions", q)
}

// ListWallets lists prepaid credit wallets and balances for a customer.
func (c *LagoClient) ListWallets(ctx context.Context, externalCustomerID string) (json.RawMessage, error) {
	q := url.Values{}
	q.Set("external_customer_id", externalCustomerID)
	return c.get(ctx, "/api/v1/wallets", q)
}

func truncate(s string, n int) string {
	if len(s) > n {
		return s[:n] + "..."
	}
	return s
}
