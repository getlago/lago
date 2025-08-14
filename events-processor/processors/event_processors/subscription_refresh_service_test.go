package event_processors

import (
	"fmt"
	"testing"

	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/tests"
	"github.com/stretchr/testify/assert"
)

var (
	refreshService *SubscriptionRefreshService
	flagStore      *tests.MockFlagStore
)

func setupRefreshServiceEnv() {
	flagStore = &tests.MockFlagStore{}

	refreshService = NewSubscriptionRefreshService(flagStore)
}

func TestFlagSubscriptionRefresh(t *testing.T) {
	setupRefreshServiceEnv()

	event := models.EnrichedEvent{
		OrganizationID: "1a901a90-1a90-1a90-1a90-1a901a901a90",
		SubscriptionID: "sub_id",
	}

	result := refreshService.FlagSubscriptionRefresh(&event)
	assert.Equal(t, 1, flagStore.ExecutionCount)
	assert.True(t, result.Success())
	assert.True(t, result.Value())

	flagStore.ReturnedError = fmt.Errorf("Failed to flag subscription")
	result = refreshService.FlagSubscriptionRefresh(&event)
	assert.Equal(t, 2, flagStore.ExecutionCount)
	assert.True(t, result.Failure())
	assert.Error(t, result.Error())
}
