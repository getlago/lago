package models

const HTTP_RUBY string = "http_ruby"

type Event struct {
	OrganizationID          string         `json:"organization_id"`
	ExternalSubscriptionId  string         `json:"external_subscription_id"`
	TransactionID           string         `json:"transaction_id"`
	Timestamp               any            `json:"timestamp"`
	Code                    string         `json:"code"`
	Properties              map[string]any `json:"properties"`
	PreciseTotalAmountCents string         `json:"precise_total_amount_cents"`
	Value                   *string        `json:"value"`
	Source                  string         `json:"source,omotempty"`
}
