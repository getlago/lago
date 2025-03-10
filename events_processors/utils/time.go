package utils

import (
	"fmt"
	"math"
	"strconv"
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
