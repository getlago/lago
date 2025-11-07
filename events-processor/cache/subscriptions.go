package cache

import (
	"fmt"

	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/utils"
	"gorm.io/gorm"
)

const (
	subscriptionPrefix = "sub"
)

func (c *Cache) buildSubscriptionKey(externalID, organizationID string) string {
	return fmt.Sprintf("%s:%s:%s", subscriptionPrefix, organizationID, externalID)
}

func (c *Cache) SetSubscription(sub *models.Subscription) utils.Result[bool] {
	key := c.buildSubscriptionKey(sub.ExternalID, *sub.OrganizationID)
	return setJSON(c, key, sub)
}

func (c *Cache) GetSubscription(externalID, organizationID string) utils.Result[*models.Subscription] {
	key := c.buildSubscriptionKey(externalID, organizationID)
	return getJSON[models.Subscription](c, key)
}

func (c *Cache) LoadSubscriptionsSnapshot(db *gorm.DB) utils.Result[int] {
	return LoadSnapshot(
		c,
		"subscriptions",
		func() ([]models.Subscription, error) {
			res := models.GetAllSubscriptions(db)
			if res.Failure() {
				return nil, res.Error()
			}
			return res.Value(), nil
		},
		func(sub *models.Subscription) string {
			return c.buildSubscriptionKey(sub.ExternalID, *sub.OrganizationID)
		},
	)
}
