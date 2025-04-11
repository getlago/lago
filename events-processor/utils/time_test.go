package utils

import (
	"fmt"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

type expectedTime struct {
	timestamp   any
	parsedValue time.Time
}

func TestToTime(t *testing.T) {
	t.Run("With supported time format", func(t *testing.T) {
		valueInt, _ := time.Parse(time.RFC3339, "2025-03-03T13:03:29Z")
		valueFloat, _ := time.Parse(time.RFC3339, "2025-03-03T13:03:29.344Z")

		expectations := []expectedTime{
			expectedTime{
				timestamp:   1741007009,
				parsedValue: valueInt,
			},
			expectedTime{
				timestamp:   int64(1741007009),
				parsedValue: valueInt,
			},
			expectedTime{
				timestamp:   float64(1741007009.344),
				parsedValue: valueFloat,
			},
			expectedTime{
				timestamp:   fmt.Sprintf("%f", 1741007009.344),
				parsedValue: valueFloat,
			},
		}

		for _, test := range expectations {
			result := ToTime(test.timestamp)
			assert.True(t, result.Success())
			assert.Equal(t, test.parsedValue, result.Value())
		}
	})

	t.Run("With unsuported time format", func(t *testing.T) {
		result := ToTime("2025-03-03T13:03:29Z")
		assert.False(t, result.Success())
		assert.Equal(t, "strconv.ParseFloat: parsing \"2025-03-03T13:03:29Z\": invalid syntax", result.ErrorMsg())
	})
}

type expectedTime64 struct {
	timestamp   any
	parsedValue float64
}

func TestToFloat64Timestamp(t *testing.T) {
	t.Run("With supported time format", func(t *testing.T) {
		expectations := []expectedTime64{
			expectedTime64{
				timestamp:   1741007009,
				parsedValue: 1741007009.0,
			},
			expectedTime64{
				timestamp:   int64(1741007009),
				parsedValue: 1741007009.0,
			},
			expectedTime64{
				timestamp:   float64(1741007009.344),
				parsedValue: 1741007009.344,
			},
			expectedTime64{
				timestamp:   fmt.Sprintf("%f", 1741007009.344),
				parsedValue: 1741007009.344,
			},
		}

		for _, test := range expectations {
			result := ToFloat64Timestamp(test.timestamp)
			assert.True(t, result.Success())
			assert.Equal(t, test.parsedValue, result.Value())
		}
	})

	t.Run("With unsuported time format", func(t *testing.T) {
		result := ToFloat64Timestamp("2025-03-03T13:03:29Z")
		assert.False(t, result.Success())
		assert.Equal(t, "strconv.ParseFloat: parsing \"2025-03-03T13:03:29Z\": invalid syntax", result.ErrorMsg())
	})
}

func TestCustomTime(t *testing.T) {
	t.Run("With expected time format", func(t *testing.T) {
		ct := &CustomTime{}

		time := "2025-03-03T13:03:29"
		err := ct.UnmarshalJSON([]byte(time))
		assert.NoError(t, err)
		assert.Equal(t, time, ct.String())

		json, err := ct.MarshalJSON()
		assert.NoError(t, err)

		data := make([]byte, 0, 21)
		assert.Equal(t, json, fmt.Appendf(data, "\"%s\"", time))
	})

	t.Run("With invalid time format", func(t *testing.T) {
		ct := &CustomTime{}

		time := "2025-03-03T13:03:29Z"
		err := ct.UnmarshalJSON([]byte(time))
		assert.Error(t, err)
	})

	t.Run("When timestamp is a unix timestamp sent as string", func(t *testing.T) {
		ct := &CustomTime{}
		time := "1744335427"
		expectedTime := "2025-04-11T01:37:07"

		err := ct.UnmarshalJSON([]byte(time))
		assert.NoError(t, err)
		assert.Equal(t, expectedTime, ct.String())

		json, err := ct.MarshalJSON()
		assert.NoError(t, err)

		data := make([]byte, 0, 21)
		assert.Equal(t, json, fmt.Appendf(data, "\"%s\"", expectedTime))
	})
}
