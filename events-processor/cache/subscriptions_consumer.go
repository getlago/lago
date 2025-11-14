package cache

import (
	"context"

	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/utils"
)

func (c *Cache) StartSubscriptionsConsumer(ctx context.Context) error {
	return startGenericConsumer(ctx, c, ConsumerConfig[models.Subscription]{
		Topic:     "lago_proc_cdc.public.subscriptions",
		ModelName: "subscription",
		IsDeleted: func(sub *models.Subscription) bool {
			return sub.TerminatedAt.Valid
		},
		GetKey: func(sub *models.Subscription) string {
			return c.buildSubscriptionKey(*sub.OrganizationID, sub.ExternalID, sub.ID)
		},
		GetID: func(sub *models.Subscription) string {
			return sub.ID
		},
		GetUpdatedAt: func(sub *models.Subscription) int64 {
			return sub.UpdatedAt.Time.UnixMilli()
		},
		GetCached: func(sub *models.Subscription) utils.Result[*models.Subscription] {
			return c.GetSubscription(*sub.OrganizationID, sub.ExternalID, sub.ID)
		},
		SetCache: func(sub *models.Subscription) utils.Result[bool] {
			return c.SetSubscription(sub)
		},
	})
}
