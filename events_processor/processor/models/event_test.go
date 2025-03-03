package models

import (
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestTimeStampAsTime(t *testing.T) {
	expectedTime, _ := time.Parse(time.RFC3339, "2025-03-03T14:03:29Z")

	event := Event{
		Timestamp: int(expectedTime.Unix()),
	}

	assert.Equal(t, expectedTime, event.TimestampAsTime())
}
