package events_processor

import (
	"context"
	"fmt"

	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/utils"
)

type SubscriptionRefreshService struct {
	flagStore models.Flagger
}

func NewSubscriptionRefreshService(flagStore models.Flagger) *SubscriptionRefreshService {
	return &SubscriptionRefreshService{
		flagStore: flagStore,
	}
}

func (s *SubscriptionRefreshService) FlagSubscriptionRefresh(ctx context.Context, event *models.EnrichedEvent) utils.Result[bool] {
	err := s.flagStore.Flag(ctx, fmt.Sprintf("%s:%s", event.OrganizationID, event.SubscriptionID))
	if err != nil {
		return utils.FailedBoolResult(err)
	}

	return utils.SuccessResult(true)
}
