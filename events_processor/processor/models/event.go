package models

import (
	"fmt"
	"math"
	"strconv"
	"time"

	"github.com/getlago/lago/events-processor/utils"
)

const HTTP_RUBY string = "http_ruby"

type Event struct {
	OrganizationID          string         `json:"organization_id"`
	ExternalSubscriptionID  string         `json:"external_subscription_id"`
	TransactionID           string         `json:"transaction_id"`
	Timestamp               any            `json:"timestamp"`
	Code                    string         `json:"code"`
	Properties              map[string]any `json:"properties"`
	PreciseTotalAmountCents string         `json:"precise_total_amount_cents"`
	Value                   *string        `json:"value"`
	Source                  string         `json:"source,omotempty"`
}

func (ev *Event) TimestampAsTime() utils.Result[time.Time] {
	var seconds int64
	var nanoseconds int64

	switch timestamp := ev.Timestamp.(type) {
	case string:
		floatTimestamp, err := strconv.ParseFloat(timestamp, 64)
		if err != nil {
			return utils.FailedResult[time.Time](err)
		}

		seconds = int64(floatTimestamp)
		nanoseconds = int64((floatTimestamp - float64(seconds)) * 1e9)

	case int:
		seconds = int64(timestamp)
		nanoseconds = 0

	case int64:
		seconds = timestamp
		nanoseconds = 0

	case float64:
		seconds = int64(timestamp)
		nanoseconds = int64((timestamp - float64(seconds)) * 1e9)

	default:
		return utils.FailedResult[time.Time](fmt.Errorf("Unsupported timestamp type: %T", ev.Timestamp))
	}

	return utils.SuccessResult(time.Unix(seconds, nanoseconds).In(time.UTC).Truncate(time.Millisecond))
}

type FailedEvent struct {
	Event               Event  `json:"event"`
	InitialErrorMessage string `json:"initial_error_message"`
	ErrorMessage        string `json:"error_message"`
	ErrorCode           string `json:"error_code"`
}

func roundToDecimalPlaces(num float64, places int) float64 {
	shift := math.Pow10(places)
	return math.Round(num*shift) / shift
}
