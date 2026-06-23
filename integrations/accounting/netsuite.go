package accounting

import (
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"os"
	"sort"
	"strconv"
	"strings"
	"time"
)

// register NetSuite as a selectable target. It builds from NETSUITE_* env vars,
// so it appears in the Gridiron ERP selector even before any HTTP call is made;
// Post returns a clear error if the credentials are not configured.
func init() {
	Register("netsuite", func() AccountingTarget { return NewNetSuiteFromEnv() })
}

// NetSuiteConfig holds SuiteTalk REST + OAuth 1.0a Token-Based-Auth credentials.
type NetSuiteConfig struct {
	AccountID      string // OAuth realm, e.g. "1234567" or "1234567_SB1"
	BaseURL        string // e.g. https://1234567.suitetalk.api.netsuite.com
	RecordType     string // REST record type to upsert (default "customerPayment")
	ConsumerKey    string
	ConsumerSecret string
	TokenID        string
	TokenSecret    string
	HTTPClient     *http.Client
}

// NetSuiteTarget posts accounting entries to NetSuite via the REST record API.
//
// Idempotency uses NetSuite's externalId upsert: PUT .../record/v1/{type}/eid:{key}
// creates-or-updates the single record for that externalId, so posting the same
// key twice books it exactly once — satisfying the AccountingTarget contract.
type NetSuiteTarget struct {
	cfg    NetSuiteConfig
	client *http.Client
}

// NewNetSuiteTarget builds a target from explicit config.
func NewNetSuiteTarget(cfg NetSuiteConfig) *NetSuiteTarget {
	if cfg.RecordType == "" {
		cfg.RecordType = "customerPayment"
	}
	cfg.BaseURL = strings.TrimRight(cfg.BaseURL, "/")
	client := cfg.HTTPClient
	if client == nil {
		client = &http.Client{Timeout: 15 * time.Second}
	}
	return &NetSuiteTarget{cfg: cfg, client: client}
}

// NewNetSuiteFromEnv builds a target from NETSUITE_* environment variables.
func NewNetSuiteFromEnv() *NetSuiteTarget {
	return NewNetSuiteTarget(NetSuiteConfig{
		AccountID:      os.Getenv("NETSUITE_ACCOUNT_ID"),
		BaseURL:        os.Getenv("NETSUITE_BASE_URL"),
		RecordType:     os.Getenv("NETSUITE_RECORD_TYPE"),
		ConsumerKey:    os.Getenv("NETSUITE_CONSUMER_KEY"),
		ConsumerSecret: os.Getenv("NETSUITE_CONSUMER_SECRET"),
		TokenID:        os.Getenv("NETSUITE_TOKEN_ID"),
		TokenSecret:    os.Getenv("NETSUITE_TOKEN_SECRET"),
	})
}

// Name identifies the target in the selector.
func (n *NetSuiteTarget) Name() string { return "netsuite" }

func (n *NetSuiteTarget) configured() error {
	var missing []string
	for name, v := range map[string]string{
		"NETSUITE_BASE_URL":        n.cfg.BaseURL,
		"NETSUITE_ACCOUNT_ID":      n.cfg.AccountID,
		"NETSUITE_CONSUMER_KEY":    n.cfg.ConsumerKey,
		"NETSUITE_CONSUMER_SECRET": n.cfg.ConsumerSecret,
		"NETSUITE_TOKEN_ID":        n.cfg.TokenID,
		"NETSUITE_TOKEN_SECRET":    n.cfg.TokenSecret,
	} {
		if v == "" {
			missing = append(missing, name)
		}
	}
	if len(missing) > 0 {
		sort.Strings(missing)
		return fmt.Errorf("netsuite: not configured (missing %s)", strings.Join(missing, ", "))
	}
	return nil
}

// Post upserts the entry into NetSuite by externalId (idempotent). The JSON body
// is a minimal template — map it to your NetSuite record schema as needed; the
// idempotency, auth, and transport are production-ready as written.
func (n *NetSuiteTarget) Post(ctx context.Context, entry AccountingEntry) error {
	if err := n.configured(); err != nil {
		return err
	}
	if entry.IdempotencyKey == "" {
		return ErrNoIdempotencyKey
	}

	endpoint := fmt.Sprintf("%s/services/rest/record/v1/%s/eid:%s",
		n.cfg.BaseURL, url.PathEscape(n.cfg.RecordType), url.PathEscape(entry.IdempotencyKey))

	payload := map[string]any{
		"externalId": entry.IdempotencyKey,
		"memo":       fmt.Sprintf("Lago usage %s (subscription %s)", entry.Code, entry.ExternalSubscriptionID),
		"amount":     float64(entry.AmountCents) / 100.0,
		"currency":   map[string]any{"refName": entry.Currency},
		"tranDate":   entry.OccurredAt.UTC().Format("2006-01-02"),
	}
	body, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("netsuite: marshal payload: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPut, endpoint, bytes.NewReader(body))
	if err != nil {
		return fmt.Errorf("netsuite: build request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", n.authHeader(http.MethodPut, endpoint))
	return doJSONRequest("netsuite", n.client, req)
}

// authHeader builds an OAuth 1.0a Token-Based-Auth header (HMAC-SHA256), the
// scheme NetSuite SuiteTalk REST requires.
func (n *NetSuiteTarget) authHeader(method, rawURL string) string {
	oauth := map[string]string{
		"oauth_consumer_key":     n.cfg.ConsumerKey,
		"oauth_token":            n.cfg.TokenID,
		"oauth_signature_method": "HMAC-SHA256",
		"oauth_timestamp":        strconv.FormatInt(time.Now().Unix(), 10),
		"oauth_nonce":            nonce(),
		"oauth_version":          "1.0",
	}

	u, _ := url.Parse(rawURL)
	baseURL := fmt.Sprintf("%s://%s%s", u.Scheme, u.Host, u.Path)

	// Collect oauth params + any query params, percent-encode (RFC3986), sort.
	type pair struct{ k, v string }
	var pairs []pair
	for k, v := range oauth {
		pairs = append(pairs, pair{oauthEscape(k), oauthEscape(v)})
	}
	for k, vs := range u.Query() {
		for _, v := range vs {
			pairs = append(pairs, pair{oauthEscape(k), oauthEscape(v)})
		}
	}
	sort.Slice(pairs, func(i, j int) bool {
		if pairs[i].k == pairs[j].k {
			return pairs[i].v < pairs[j].v
		}
		return pairs[i].k < pairs[j].k
	})
	parts := make([]string, len(pairs))
	for i, p := range pairs {
		parts[i] = p.k + "=" + p.v
	}
	paramString := strings.Join(parts, "&")

	baseString := strings.ToUpper(method) + "&" + oauthEscape(baseURL) + "&" + oauthEscape(paramString)
	signingKey := oauthEscape(n.cfg.ConsumerSecret) + "&" + oauthEscape(n.cfg.TokenSecret)
	mac := hmac.New(sha256.New, []byte(signingKey))
	mac.Write([]byte(baseString))
	signature := base64.StdEncoding.EncodeToString(mac.Sum(nil))

	header := []string{fmt.Sprintf(`realm="%s"`, oauthEscape(n.cfg.AccountID))}
	for k, v := range oauth {
		header = append(header, fmt.Sprintf(`%s="%s"`, oauthEscape(k), oauthEscape(v)))
	}
	header = append(header, fmt.Sprintf(`oauth_signature="%s"`, oauthEscape(signature)))
	sort.Strings(header)
	return "OAuth " + strings.Join(header, ", ")
}

// oauthEscape percent-encodes per RFC 3986 (the OAuth requirement): only
// A-Z a-z 0-9 - . _ ~ are left unescaped.
func oauthEscape(s string) string {
	var b strings.Builder
	for _, c := range []byte(s) {
		switch {
		case c >= 'A' && c <= 'Z', c >= 'a' && c <= 'z', c >= '0' && c <= '9',
			c == '-', c == '.', c == '_', c == '~':
			b.WriteByte(c)
		default:
			fmt.Fprintf(&b, "%%%02X", c)
		}
	}
	return b.String()
}

func nonce() string {
	b := make([]byte, 16)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}
