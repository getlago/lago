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

// Bigcapital is the in-house default accounting target.
func init() {
	Register("bigcapital", func() AccountingTarget { return NewBigcapitalFromEnv() })
}

// BigcapitalConfig holds Bigcapital REST API connection details. Bigcapital is
// the open-source accounting software Gridiron self-hosts, so BaseURL is your
// own deployment.
type BigcapitalConfig struct {
	BaseURL        string // e.g. https://accounting.gridiron.internal
	AccessToken    string // Bigcapital API token (x-access-token)
	OrganizationID string // Bigcapital organization id
	Resource       string // REST resource to create (default "manual-journals")
	HTTPClient     *http.Client
}

// BigcapitalTarget posts accounting entries to Bigcapital. Idempotency: it sends
// an Idempotency-Key header and a unique `reference` equal to the Lago
// transaction_id; Bigcapital rejects a duplicate reference (HTTP 409), which the
// shared client treats as "already booked". So the same key books once.
type BigcapitalTarget struct {
	cfg    BigcapitalConfig
	client *http.Client
}

// NewBigcapitalTarget builds a target from explicit config.
func NewBigcapitalTarget(cfg BigcapitalConfig) *BigcapitalTarget {
	if cfg.Resource == "" {
		cfg.Resource = "manual-journals"
	}
	cfg.BaseURL = strings.TrimRight(cfg.BaseURL, "/")
	client := cfg.HTTPClient
	if client == nil {
		client = &http.Client{Timeout: 15 * time.Second}
	}
	return &BigcapitalTarget{cfg: cfg, client: client}
}

// NewBigcapitalFromEnv builds a target from BIGCAPITAL_* environment variables.
func NewBigcapitalFromEnv() *BigcapitalTarget {
	return NewBigcapitalTarget(BigcapitalConfig{
		BaseURL:        os.Getenv("BIGCAPITAL_BASE_URL"),
		AccessToken:    os.Getenv("BIGCAPITAL_ACCESS_TOKEN"),
		OrganizationID: os.Getenv("BIGCAPITAL_ORGANIZATION_ID"),
		Resource:       os.Getenv("BIGCAPITAL_RESOURCE"),
	})
}

// Name identifies the target in the selector.
func (b *BigcapitalTarget) Name() string { return "bigcapital" }

func (b *BigcapitalTarget) configured() error {
	var missing []string
	if b.cfg.BaseURL == "" {
		missing = append(missing, "BIGCAPITAL_BASE_URL")
	}
	if b.cfg.AccessToken == "" {
		missing = append(missing, "BIGCAPITAL_ACCESS_TOKEN")
	}
	if b.cfg.OrganizationID == "" {
		missing = append(missing, "BIGCAPITAL_ORGANIZATION_ID")
	}
	if len(missing) > 0 {
		return fmt.Errorf("bigcapital: not configured (missing %s)", strings.Join(missing, ", "))
	}
	return nil
}

// Post creates a manual journal in Bigcapital, keyed for idempotency by the Lago
// transaction_id. The JSON body is a minimal template - map `entries` to your
// Bigcapital chart of accounts; auth/idempotency/transport are production-ready.
func (b *BigcapitalTarget) Post(ctx context.Context, entry AccountingEntry) error {
	if err := b.configured(); err != nil {
		return err
	}
	if entry.IdempotencyKey == "" {
		return ErrNoIdempotencyKey
	}

	endpoint := fmt.Sprintf("%s/api/%s", b.cfg.BaseURL, b.cfg.Resource)
	amount := float64(entry.AmountCents) / 100.0
	payload := map[string]any{
		"date":          entry.OccurredAt.UTC().Format("2006-01-02"),
		"reference":     entry.IdempotencyKey,
		"currency_code": entry.Currency,
		"memo":          fmt.Sprintf("Lago usage %s (subscription %s)", entry.Code, entry.ExternalSubscriptionID),
		"entries": []any{
			map[string]any{"index": 1, "credit": amount, "account_id": 1},
			map[string]any{"index": 2, "debit": amount, "account_id": 2},
		},
	}
	body, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("bigcapital: marshal payload: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(body))
	if err != nil {
		return fmt.Errorf("bigcapital: build request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("x-access-token", b.cfg.AccessToken)
	req.Header.Set("organization-id", b.cfg.OrganizationID)
	req.Header.Set("Idempotency-Key", entry.IdempotencyKey)
	return doJSONRequest("bigcapital", b.client, req)
}
