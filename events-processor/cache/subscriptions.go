package cache

import (
	"fmt"
	"time"

	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/utils"
	"gorm.io/gorm"
)

const (
	subscriptionPrefix = "sub"
)

func (c *Cache) buildSubscriptionKey(organizationID, externalID, ID string) string {
	return fmt.Sprintf("%s:%s:%s:%s", subscriptionPrefix, organizationID, externalID, ID)
}

func (c *Cache) SetSubscription(sub *models.Subscription) utils.Result[bool] {
	key := c.buildSubscriptionKey(*sub.OrganizationID, sub.ExternalID, sub.ID)
	return setJSON(c, key, sub)
}

func (c *Cache) GetSubscription(organizationID, externalID, ID string) utils.Result[*models.Subscription] {
	key := c.buildSubscriptionKey(organizationID, externalID, ID)
	return getJSON[models.Subscription](c, key)
}

// Since we want to keep terminated subscriptions to permit grace period events backfill
// we update the cache entry with a 1 month TTL
func (c *Cache) DeleteSubscription(sub *models.Subscription) utils.Result[bool] {
	key := c.buildSubscriptionKey(*sub.OrganizationID, sub.ExternalID, sub.ID)
	return deleteWithTTL(c, key, sub, time.Hour)
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
			return c.buildSubscriptionKey(*sub.OrganizationID, sub.ExternalID, sub.ID)
		},
	)
}
