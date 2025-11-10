package utils

import (
	"database/sql"
	"database/sql/driver"
	"encoding/json"
	"fmt"
	"math"
	"strconv"
	"strings"
	"time"
)

func ToTime(timestamp any) Result[time.Time] {
	var seconds int64
	var nanoseconds int64

	switch timestamp := timestamp.(type) {
	case string:
		floatTimestamp, err := strconv.ParseFloat(timestamp, 64)
		if err != nil {
			return FailedResult[time.Time](err)
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
		return FailedResult[time.Time](fmt.Errorf("Unsupported timestamp type: %T", timestamp))
	}

	return SuccessResult(time.Unix(seconds, nanoseconds).In(time.UTC).Truncate(time.Millisecond))
}

func ToFloat64Timestamp(timeValue any) Result[float64] {
	var value float64

	switch timestamp := timeValue.(type) {
	case string:
		floatTimestamp, err := strconv.ParseFloat(timestamp, 64)
		if err != nil {
			return FailedResult[float64](err)
		}
		value = math.Trunc(floatTimestamp*1000) / 1000
	case int:
		value = float64(timestamp)
	case int64:
		value = float64(timestamp)
	case float64:
		value = float64(timestamp)
	default:
		return FailedResult[float64](fmt.Errorf("Unsupported timestamp type: %T", timestamp))
	}

	return SuccessResult(value)
}

type CustomTime time.Time

func (ct *CustomTime) UnmarshalJSON(b []byte) error {
	s := strings.Trim(string(b), "\"")
	if s == "null" || s == "" {
		return nil
	}

	t, err := time.Parse("2006-01-02T15:04:05", s)
	if err != nil {
		// value could be a Unix timestamp encoded as a string
		timeResult := ToTime(s)
		if timeResult.Failure() {
			return err
		}

		t = timeResult.value
	}

	*ct = CustomTime(t)
	return nil
}

func (ct CustomTime) MarshalJSON() ([]byte, error) {
	t := time.Time(ct)
	if t.IsZero() {
		return []byte("null"), nil
	}

	data := make([]byte, 0, 21) // 19 characters for time format and 2 for quotes
	return fmt.Appendf(data, "\"%s\"", t.Format("2006-01-02T15:04:05")), nil
}

func (ct CustomTime) Time() time.Time {
	return time.Time(ct)
}

func (ct CustomTime) String() string {
	return ct.Time().Format("2006-01-02T15:04:05")
}

type NullTime struct {
	sql.NullTime
}

func (nt *NullTime) Scan(value interface{}) error {
	return nt.NullTime.Scan(value)
}

func (nt NullTime) Value() (driver.Value, error) {
	return nt.NullTime.Value()
}

func (nt *NullTime) MarshalJSON() ([]byte, error) {
	if !nt.Valid {
		return []byte("null"), nil
	}
	return json.Marshal(nt.Time.UnixMicro())
}

func (nt *NullTime) UnmarshalJSON(data []byte) error {
	if string(data) == "null" {
		nt.Valid = false
		return nil
	}

	// Try to parse as int64 (microseconds)
	var microseconds int64
	if err := json.Unmarshal(data, &microseconds); err == nil {
		nt.Time = time.UnixMicro(microseconds).UTC()
		nt.Valid = true
		return nil
	}

	// Try to parse timestamp as string
	var timestampStr string
	if err := json.Unmarshal(data, &timestampStr); err != nil {
		return err
	}

	if timestampStr == "" {
		nt.Valid = false
		return nil
	}

	if t, err := time.Parse(time.RFC3339, timestampStr); err == nil {
		nt.Time = t
		nt.Valid = true
		return nil
	}

	return fmt.Errorf("unable to parse timestamp string: %s", timestampStr)
}

func NewNullTime(t time.Time) NullTime {
	return NullTime{
		NullTime: sql.NullTime{
			Time:  t,
			Valid: true,
		},
	}
}

func NowNullTime() NullTime {
	return NewNullTime(time.Now())
}
