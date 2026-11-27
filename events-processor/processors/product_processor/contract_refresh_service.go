package product_processor

import (
	"context"
	"fmt"

	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/utils"
)

// ContractRefreshService adds the contract of an event to the contract_refreshed_v1
// sorted set, which the API reads to evaluate the alerts of the contract.
type ContractRefreshService struct {
	flagStore models.Flagger
}

// NewContractRefreshService takes a nil flagStore when the Redis store is not
// configured: the pipeline then flags no contract.
func NewContractRefreshService(flagStore models.Flagger) *ContractRefreshService {
	return &ContractRefreshService{
		flagStore: flagStore,
	}
}

// FlagContractRefresh flags the organization and external contract id of the event.
// Its value is false when there is no flag store.
func (s *ContractRefreshService) FlagContractRefresh(ctx context.Context, event *models.ProductEnrichedEvent) utils.Result[bool] {
	if s.flagStore == nil {
		return utils.SuccessResult(false)
	}

	err := s.flagStore.Flag(ctx, fmt.Sprintf("%s:%s", event.OrganizationID, event.ExternalContractID))
	if err != nil {
		return utils.FailedBoolResult(err)
	}

	return utils.SuccessResult(true)
}
