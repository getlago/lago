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
	ExternalContractID      string           `json:"external_contract_id,omitempty"`
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

	OrganizationID          string         `json:"organization_id"`
	ExternalSubscriptionID  string         `json:"external_subscription_id"`
	SubscriptionID          string         `json:"subscription_id"`
	PlanID                  string         `json:"plan_id"`
	TransactionID           string         `json:"transaction_id"`
	Code                    string         `json:"code"`
	AggregationType         string         `json:"aggregation_type"`
	Properties              map[string]any `json:"properties"`
	PreciseTotalAmountCents string         `json:"precise_total_amount_cents"`
	Source                  string         `json:"source,omitempty"`
	Value                   *string        `json:"value"`
	Timestamp               float64        `json:"timestamp"`
	TimestampStr            string         `json:"-"`
	Time                    time.Time      `json:"-"`
}

// CatalogEnrichedEvent is what the catalog pipeline writes to
// catalog_events_enriched: one row per event, keyed by contract, with rate
// cards and product filters matched when the API reads.
type CatalogEnrichedEvent struct {
	InitialEvent *Event `json:"-"`

	OrganizationID          string         `json:"organization_id"`
	ExternalContractID      string         `json:"external_contract_id"`
	ContractID              *string        `json:"contract_id"`
	TransactionID           string         `json:"transaction_id"`
	Code                    string         `json:"code"`
	AggregationType         string         `json:"aggregation_type"`
	Properties              map[string]any `json:"properties"`
	PreciseTotalAmountCents string         `json:"precise_total_amount_cents"`
	Source                  string         `json:"source,omitempty"`
	Value                   *string        `json:"value"`
	Timestamp               float64        `json:"timestamp"`
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

func (er *EnrichedEvent) ToCatalogEnrichedEvent(contract *Contract) *CatalogEnrichedEvent {
	catalogEvent := &CatalogEnrichedEvent{
		InitialEvent:            er.InitialEvent,
		OrganizationID:          er.OrganizationID,
		ExternalContractID:      er.InitialEvent.ExternalContractID,
		TransactionID:           er.TransactionID,
		Code:                    er.Code,
		AggregationType:         er.AggregationType,
		Properties:              er.Properties,
		PreciseTotalAmountCents: er.PreciseTotalAmountCents,
		Source:                  er.Source,
		Value:                   er.Value,
		Timestamp:               er.Timestamp,
	}

	if contract != nil {
		catalogEvent.ContractID = &contract.ID
	}

	return catalogEvent
}

func (ev *Event) NotAPIPostProcessed() bool {
	if ev.Source != HTTP_RUBY {
		return true
	}

	return ev.SourceMetadata == nil || !ev.SourceMetadata.ApiPostProcess
}
