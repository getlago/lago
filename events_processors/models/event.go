package models

import (
	"time"

	"github.com/getlago/lago/events-processors/utils"
)

const HTTP_RUBY string = "http_ruby"

type Event struct {
	OrganizationID          string         `json:"organization_id"`
	ExternalSubscriptionID  string         `json:"external_subscription_id"`
	TransactionID           string         `json:"transaction_id"`
	Code                    string         `json:"code"`
	Properties              map[string]any `json:"properties"`
	PreciseTotalAmountCents string         `json:"precise_total_amount_cents"`
	Source                  string         `json:"source,omotempty"`
	Timestamp               any            `json:"timestamp"`
}

type EnrichedEvent struct {
	OrganizationID          string         `json:"organization_id"`
	ExternalSubscriptionID  string         `json:"external_subscription_id"`
	TransactionID           string         `json:"transaction_id"`
	Code                    string         `json:"code"`
	Properties              map[string]any `json:"properties"`
	PreciseTotalAmountCents string         `json:"precise_total_amount_cents"`
	Source                  string         `json:"source,omotempty"`
	Timestamp               float64        `json:"timestamp"`
	Value                   *string        `json:"value"`
	Time                    time.Time
}

type FailedEvent struct {
	Event               Event  `json:"event"`
	InitialErrorMessage string `json:"initial_error_message"`
	ErrorMessage        string `json:"error_message"`
	ErrorCode           string `json:"error_code"`
}

func (ev *Event) ToEnrichedEvent() utils.Result[*EnrichedEvent] {
	er := &EnrichedEvent{
		OrganizationID:          ev.OrganizationID,
		ExternalSubscriptionID:  ev.ExternalSubscriptionID,
		TransactionID:           ev.TransactionID,
		Code:                    ev.Code,
		Properties:              ev.Properties,
		PreciseTotalAmountCents: ev.PreciseTotalAmountCents,
		Source:                  ev.Source,
	}

	timestampResult := utils.ToFloat64Timestamp(ev.Timestamp)
	if timestampResult.Failure() {
		return utils.FailedResult[*EnrichedEvent](timestampResult.Error())
	}
	er.Timestamp = timestampResult.Value()

	timeResult := utils.ToTime(ev.Timestamp)
	if timeResult.Failure() {
		return utils.FailedResult[*EnrichedEvent](timeResult.Error())
	}
	er.Time = timeResult.Value()

	return utils.SuccessResult(er)
}
