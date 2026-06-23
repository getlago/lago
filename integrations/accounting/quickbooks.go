package accounting

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"os"
	"strings"
	"time"
)

func init() {
	Register("quickbooks", func() AccountingTarget { return NewQuickBooksFromEnv() })
}

// QuickBooksConfig holds QuickBooks Online connection details. AccessToken is an
// OAuth2 bearer token (refresh is handled upstream / by secret rotation).
type QuickBooksConfig struct {
	BaseURL      string // default https://quickbooks.api.intuit.com
	RealmID      string // QBO company id
	AccessToken  string // OAuth2 bearer access token
	Entity       string // entity to create (default "journalentry")
	MinorVersion string // QBO API minor version (default "73")
	HTTPClient   *http.Client
}

// QuickBooksTarget posts to the QuickBooks Online API. Idempotency uses QBO's
// native idempotent-create: the same `requestid` query parameter returns the
// same result, so posting one key twice books it once.
type QuickBooksTarget struct {
	cfg    QuickBooksConfig
	client *http.Client
}

// NewQuickBooksTarget builds a target from explicit config.
func NewQuickBooksTarget(cfg QuickBooksConfig) *QuickBooksTarget {
	if cfg.BaseURL == "" {
		cfg.BaseURL = "https://quickbooks.api.intuit.com"
	}
	if cfg.Entity == "" {
		cfg.Entity = "journalentry"
	}
	if cfg.MinorVersion == "" {
		cfg.MinorVersion = "73"
	}
	cfg.BaseURL = strings.TrimRight(cfg.BaseURL, "/")
	client := cfg.HTTPClient
	if client == nil {
		client = &http.Client{Timeout: 15 * time.Second}
	}
	return &QuickBooksTarget{cfg: cfg, client: client}
}

// NewQuickBooksFromEnv builds a target from QUICKBOOKS_* environment variables.
func NewQuickBooksFromEnv() *QuickBooksTarget {
	return NewQuickBooksTarget(QuickBooksConfig{
		BaseURL:     os.Getenv("QUICKBOOKS_BASE_URL"),
		RealmID:     os.Getenv("QUICKBOOKS_REALM_ID"),
		AccessToken: os.Getenv("QUICKBOOKS_ACCESS_TOKEN"),
		Entity:      os.Getenv("QUICKBOOKS_ENTITY"),
	})
}

// Name identifies the target in the selector.
func (q *QuickBooksTarget) Name() string { return "quickbooks" }

func (q *QuickBooksTarget) configured() error {
	var missing []string
	if q.cfg.RealmID == "" {
		missing = append(missing, "QUICKBOOKS_REALM_ID")
	}
	if q.cfg.AccessToken == "" {
		missing = append(missing, "QUICKBOOKS_ACCESS_TOKEN")
	}
	if len(missing) > 0 {
		return fmt.Errorf("quickbooks: not configured (missing %s)", strings.Join(missing, ", "))
	}
	return nil
}

// Post creates a JournalEntry in QuickBooks Online, made idempotent by the
// `requestid` query parameter. The JSON body is a minimal template - map the
// lines to your QBO chart of accounts.
func (q *QuickBooksTarget) Post(ctx context.Context, entry AccountingEntry) error {
	if err := q.configured(); err != nil {
		return err
	}
	if entry.IdempotencyKey == "" {
		return ErrNoIdempotencyKey
	}

	endpoint := fmt.Sprintf("%s/v3/company/%s/%s?minorversion=%s&requestid=%s",
		q.cfg.BaseURL, url.PathEscape(q.cfg.RealmID), url.PathEscape(q.cfg.Entity),
		url.QueryEscape(q.cfg.MinorVersion), url.QueryEscape(entry.IdempotencyKey))

	amount := float64(entry.AmountCents) / 100.0
	payload := map[string]any{
		"PrivateNote": fmt.Sprintf("Lago txn %s usage %s (subscription %s)", entry.IdempotencyKey, entry.Code, entry.ExternalSubscriptionID),
		"Line": []any{
			map[string]any{
				"Amount":      amount,
				"DetailType":  "JournalEntryLineDetail",
				"Description": entry.Code,
				"JournalEntryLineDetail": map[string]any{
					"PostingType": "Debit",
				},
			},
		},
	}
	body, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("quickbooks: marshal payload: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(body))
	if err != nil {
		return fmt.Errorf("quickbooks: build request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")
	req.Header.Set("Authorization", "Bearer "+q.cfg.AccessToken)
	return doJSONRequest("quickbooks", q.client, req)
}
