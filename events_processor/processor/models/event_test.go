package models

import (
	"fmt"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

type expectedTimestamp struct {
	timestamp   any
	parsedValue time.Time
}

func TestTimeStampAsTime(t *testing.T) {
	valueInt, _ := time.Parse(time.RFC3339, "2025-03-03T13:03:29Z")
	valueFloat, _ := time.Parse(time.RFC3339, "2025-03-03T13:03:29.344Z")

	expectations := []expectedTimestamp{
		expectedTimestamp{
			timestamp:   1741007009,
			parsedValue: valueInt,
		},
		expectedTimestamp{
			timestamp:   int64(1741007009),
			parsedValue: valueInt,
		},
		expectedTimestamp{
			timestamp:   float64(1741007009.344),
			parsedValue: valueFloat,
		},
		expectedTimestamp{
			timestamp:   fmt.Sprintf("%f", 1741007009.344),
			parsedValue: valueFloat,
		},
	}

	for _, test := range expectations {
		event := Event{Timestamp: test.timestamp}

		result := event.TimestampAsTime()
		assert.True(t, result.Success())
		assert.Equal(t, test.parsedValue, result.Value())
	}
}

func TestTimeStampAsTimeWithUnsuportedFormat(t *testing.T) {
	event := Event{Timestamp: "2025-03-03T13:03:29Z"}
	result := event.TimestampAsTime()
	assert.False(t, result.Success())
	assert.Equal(t, "strconv.ParseFloat: parsing \"2025-03-03T13:03:29Z\": invalid syntax", result.ErrorMsg())
}
