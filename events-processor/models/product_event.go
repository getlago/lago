package models

import (
	"time"

	"github.com/getlago/lago/events-processor/utils"
)

// ProductEvent is a raw event of a product catalog organization: the same
// payload as Event, keyed by contract instead of subscription.
type ProductEvent struct {
	OrganizationID          string           `json:"organization_id"`
	ExternalContractID      string           `json:"external_contract_id"`
	TransactionID           string           `json:"transaction_id"`
	Code                    string           `json:"code"`
	Properties              map[string]any   `json:"properties"`
	PreciseTotalAmountCents string           `json:"precise_total_amount_cents"`
	Source                  string           `json:"source,omitempty"`
	Timestamp               any              `json:"timestamp"`
	SourceMetadata          *SourceMetadata  `json:"source_metadata"`
	IngestedAt              utils.CustomTime `json:"ingested_at"`
}

// ProductEnrichedEvent is what the product events pipeline writes to
// product_events_enriched: one row per event, keyed by contract, with rate
// cards and product filters matched when the API reads.
type ProductEnrichedEvent struct {
	InitialEvent   *ProductEvent   `json:"-"`
	BillableMetric *BillableMetric `json:"-"`

	OrganizationID          string         `json:"organization_id"`
	ExternalContractID      string         `json:"external_contract_id"`
	TransactionID           string         `json:"transaction_id"`
	Code                    string         `json:"code"`
	AggregationType         string         `json:"aggregation_type"`
	Properties              map[string]any `json:"properties"`
	PreciseTotalAmountCents string         `json:"precise_total_amount_cents"`
	Source                  string         `json:"source,omitempty"`
	Value                   *string        `json:"value"`
	Timestamp               float64        `json:"timestamp"`
}

func (ev *ProductEvent) IngestedTime() time.Time {
	return ev.IngestedAt.Time()
}

func (ev *ProductEvent) ToProductEnrichedEvent() utils.Result[*ProductEnrichedEvent] {
	er := &ProductEnrichedEvent{
		InitialEvent:            ev,
		OrganizationID:          ev.OrganizationID,
		ExternalContractID:      ev.ExternalContractID,
		TransactionID:           ev.TransactionID,
		Code:                    ev.Code,
		Properties:              ev.Properties,
		PreciseTotalAmountCents: ev.PreciseTotalAmountCents,
		Source:                  ev.Source,
	}

	timestampResult := utils.ToFloat64Timestamp(ev.Timestamp)
	if timestampResult.Failure() {
		return utils.FailedResult[*ProductEnrichedEvent](timestampResult.Error()).NonRetryable()
	}
	er.Timestamp = timestampResult.Value()

	return utils.SuccessResult(er)
}

func (er *ProductEnrichedEvent) GetSource() string {
	return er.Source
}

func (er *ProductEnrichedEvent) GetProperties() map[string]any {
	return er.Properties
}

func (er *ProductEnrichedEvent) SetBillableMetric(bm *BillableMetric) {
	er.BillableMetric = bm
	er.AggregationType = bm.AggregationType.String()
}

func (er *ProductEnrichedEvent) SetValue(value *string) {
	er.Value = value
}
