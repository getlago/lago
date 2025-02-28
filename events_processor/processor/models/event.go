package models

import "time"

const HTTP_RUBY string = "http_ruby"

type Event struct {
	OrganizationID          string         `json:"organization_id"`
	ExternalSubscriptionID  string         `json:"external_subscription_id"`
	TransactionID           string         `json:"transaction_id"`
	Timestamp               int            `json:"timestamp"`
	Code                    string         `json:"code"`
	Properties              map[string]any `json:"properties"`
	PreciseTotalAmountCents string         `json:"precise_total_amount_cents"`
	Value                   *string        `json:"value"`
	Source                  string         `json:"source,omotempty"`
}

func (ev *Event) TimestampAsTime() time.Time {
	return time.Unix(int64(ev.Timestamp), 0)
}

type FailedEvent struct {
	Event               Event  `json:"event"`
	InitialErrorMessage string `json:"initial_error_message"`
	ErrorMessage        string `json:"error_message"`
	ErrorCode           string `json:"error_code"`
}
