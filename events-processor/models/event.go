package models

import (
	"fmt"
	"time"

	"github.com/getlago/lago/events-processor/utils"
)

const HTTP_RUBY string = "http_ruby"

type Event struct {
	OrganizationID          string           `json:"organization_id"`
	ExternalSubscriptionID  string           `json:"external_subscription_id"`
	TransactionID           string           `json:"transaction_id"`
	Code                    string           `json:"code"`
	Properties              map[string]any   `json:"properties"`
	PreciseTotalAmountCents string           `json:"precise_total_amount_cents"`
	Source                  string           `json:"source,omitempty"`
	Timestamp               any              `json:"timestamp"`
	SourceMetadata          *SourceMetadata  `json:"source_metadata"`
	IngestedAt              utils.CustomTime `json:"ingested_at"`
}

type SourceMetadata struct {
	ApiPostProcess bool `json:"api_post_processed"`
}

type EnrichedEvent struct {
	InitialEvent   *Event          `json:"-"`
	BillableMetric *BillableMetric `json:"-"`
	Subscription   *Subscription   `json:"-"`
	FlatFilter     *FlatFilter     `json:"-"`

	OrganizationID          string            `json:"organization_id"`
	ExternalSubscriptionID  string            `json:"external_subscription_id"`
	SubscriptionID          string            `json:"subscription_id"`
	PlanID                  string            `json:"plan_id"`
	TransactionID           string            `json:"transaction_id"`
	Code                    string            `json:"code"`
	AggregationType         string            `json:"aggregation_type"`
	Properties              map[string]any    `json:"properties"`
	PreciseTotalAmountCents string            `json:"precise_total_amount_cents"`
	Source                  string            `json:"source,omitempty"`
	Value                   *string           `json:"value"`
	Timestamp               float64           `json:"timestamp"`
	TimestampStr            string            `json:"-"`
	Time                    time.Time         `json:"-"`
	ChargeID                *string           `json:"charge_id"`
	ChargeUpdatedAt         *time.Time        `json:"charge_updated_at"`
	ChargeFilterID          *string           `json:"charge_filter_id"`
	ChargeFilterUpdatedAt   *time.Time        `json:"charge_filter_updated_at"`
	GroupedBy               map[string]string `json:"grouped_by"`
}

type FailedEvent struct {
	Event               Event     `json:"event"`
	InitialErrorMessage string    `json:"initial_error_message"`
	ErrorMessage        string    `json:"error_message"`
	ErrorCode           string    `json:"error_code"`
	FailedAt            time.Time `json:"failed_at"`
}

func (ev *Event) ToEnrichedEvent() utils.Result[*EnrichedEvent] {
	er := &EnrichedEvent{
		InitialEvent:            ev,
		OrganizationID:          ev.OrganizationID,
		ExternalSubscriptionID:  ev.ExternalSubscriptionID,
		TransactionID:           ev.TransactionID,
		Code:                    ev.Code,
		Properties:              ev.Properties,
		PreciseTotalAmountCents: ev.PreciseTotalAmountCents,
		Source:                  ev.Source,
		GroupedBy:               make(map[string]string),
	}

	timestampResult := utils.ToFloat64Timestamp(ev.Timestamp)
	if timestampResult.Failure() {
		return utils.FailedResult[*EnrichedEvent](timestampResult.Error()).NonRetryable()
	}
	er.Timestamp = timestampResult.Value()
	er.TimestampStr = fmt.Sprintf("%f", er.Timestamp)

	timeResult := utils.ToTime(ev.Timestamp)
	if timeResult.Failure() {
		return utils.FailedResult[*EnrichedEvent](timeResult.Error()).NonRetryable()
	}
	er.Time = timeResult.Value()

	return utils.SuccessResult(er)
}

func (ev *Event) NotAPIPostProcessed() bool {
	if ev.Source != HTTP_RUBY {
		return true
	}

	return ev.SourceMetadata == nil || !ev.SourceMetadata.ApiPostProcess
}
