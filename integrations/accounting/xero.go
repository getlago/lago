package accounting

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"strings"
	"time"
)

func init() {
	Register("xero", func() AccountingTarget { return NewXeroFromEnv() })
}

// XeroConfig holds Xero Accounting API connection details. AccessToken is an
// OAuth2 bearer token (refresh handled upstream / by secret rotation).
type XeroConfig struct {
	BaseURL     string // default https://api.xero.com
	TenantID    string // Xero-Tenant-Id
	AccessToken string // OAuth2 bearer access token
	Resource    string // resource to create (default "ManualJournals")
	HTTPClient  *http.Client
}

// XeroTarget posts to the Xero Accounting API. Idempotency uses Xero's native
// `Idempotency-Key` request header, so posting one key twice books it once.
type XeroTarget struct {
	cfg    XeroConfig
	client *http.Client
}

// NewXeroTarget builds a target from explicit config.
func NewXeroTarget(cfg XeroConfig) *XeroTarget {
	if cfg.BaseURL == "" {
		cfg.BaseURL = "https://api.xero.com"
	}
	if cfg.Resource == "" {
		cfg.Resource = "ManualJournals"
	}
	cfg.BaseURL = strings.TrimRight(cfg.BaseURL, "/")
	client := cfg.HTTPClient
	if client == nil {
		client = &http.Client{Timeout: 15 * time.Second}
	}
	return &XeroTarget{cfg: cfg, client: client}
}

// NewXeroFromEnv builds a target from XERO_* environment variables.
func NewXeroFromEnv() *XeroTarget {
	return NewXeroTarget(XeroConfig{
		BaseURL:     os.Getenv("XERO_BASE_URL"),
		TenantID:    os.Getenv("XERO_TENANT_ID"),
		AccessToken: os.Getenv("XERO_ACCESS_TOKEN"),
		Resource:    os.Getenv("XERO_RESOURCE"),
	})
}

// Name identifies the target in the selector.
func (x *XeroTarget) Name() string { return "xero" }

func (x *XeroTarget) configured() error {
	var missing []string
	if x.cfg.TenantID == "" {
		missing = append(missing, "XERO_TENANT_ID")
	}
	if x.cfg.AccessToken == "" {
		missing = append(missing, "XERO_ACCESS_TOKEN")
	}
	if len(missing) > 0 {
		return fmt.Errorf("xero: not configured (missing %s)", strings.Join(missing, ", "))
	}
	return nil
}

// Post creates a ManualJournal in Xero, made idempotent by the Idempotency-Key
// header. The JSON body is a minimal template - map the lines to your Xero chart
// of accounts.
func (x *XeroTarget) Post(ctx context.Context, entry AccountingEntry) error {
	if err := x.configured(); err != nil {
		return err
	}
	if entry.IdempotencyKey == "" {
		return ErrNoIdempotencyKey
	}

	endpoint := fmt.Sprintf("%s/api.xro/2.0/%s", x.cfg.BaseURL, x.cfg.Resource)
	amount := float64(entry.AmountCents) / 100.0
	payload := map[string]any{
		"Narration": fmt.Sprintf("Lago usage %s (subscription %s) ref %s", entry.Code, entry.ExternalSubscriptionID, entry.IdempotencyKey),
		"JournalLines": []any{
			map[string]any{"LineAmount": amount, "AccountCode": "200"},
			map[string]any{"LineAmount": -amount, "AccountCode": "090"},
		},
	}
	body, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("xero: marshal payload: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(body))
	if err != nil {
		return fmt.Errorf("xero: build request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")
	req.Header.Set("Authorization", "Bearer "+x.cfg.AccessToken)
	req.Header.Set("Xero-Tenant-Id", x.cfg.TenantID)
	req.Header.Set("Idempotency-Key", entry.IdempotencyKey)
	return doJSONRequest("xero", x.client, req)
}
