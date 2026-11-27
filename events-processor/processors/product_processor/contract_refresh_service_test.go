package product_processor

import (
	"context"
	"errors"
	"testing"

	"github.com/stretchr/testify/assert"

	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/tests"
)

func TestFlagContractRefresh(t *testing.T) {
	buildEnrichedEvent := func(externalContractID string) *models.ProductEnrichedEvent {
		return &models.ProductEnrichedEvent{
			OrganizationID:     orgID,
			ExternalContractID: externalContractID,
		}
	}

	t.Run("flags the contract of the organization", func(t *testing.T) {
		flagStore := &tests.MockFlagStore{}
		service := NewContractRefreshService(flagStore)

		result := service.FlagContractRefresh(context.Background(), buildEnrichedEvent("contract_ext_id"))

		assert.True(t, result.Success())
		assert.True(t, result.Value())
		assert.Equal(t, 1, flagStore.ExecutionCount)
		assert.Equal(t, orgID+":contract_ext_id", flagStore.Key)
	})

	t.Run("keeps the external contract id as sent", func(t *testing.T) {
		flagStore := &tests.MockFlagStore{}
		service := NewContractRefreshService(flagStore)

		// The API splits the member on the first ":" and the last "|", so both can
		// appear in the external id.
		result := service.FlagContractRefresh(context.Background(), buildEnrichedEvent("ctr:2026|eu"))

		assert.True(t, result.Success())
		assert.Equal(t, orgID+":ctr:2026|eu", flagStore.Key)
	})

	t.Run("fails when the flag store fails", func(t *testing.T) {
		flagStore := &tests.MockFlagStore{ReturnedError: errors.New("connection refused")}
		service := NewContractRefreshService(flagStore)

		result := service.FlagContractRefresh(context.Background(), buildEnrichedEvent("contract_ext_id"))

		assert.True(t, result.Failure())
		assert.EqualError(t, result.Error(), "connection refused")
		assert.Equal(t, 1, flagStore.ExecutionCount)
	})

	t.Run("flags nothing without a flag store", func(t *testing.T) {
		service := NewContractRefreshService(nil)

		result := service.FlagContractRefresh(context.Background(), buildEnrichedEvent("contract_ext_id"))

		assert.True(t, result.Success())
		assert.False(t, result.Value())
	})
}
