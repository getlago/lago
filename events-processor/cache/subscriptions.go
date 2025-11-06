package cache

import (
	"encoding/json"
	"fmt"
	"log/slog"
	"time"

	"github.com/dgraph-io/badger/v4"
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

	data, err := json.Marshal(sub)
	if err != nil {
		return utils.FailedBoolResult(err)
	}

	err = c.db.Update(func(txn *badger.Txn) error {
		return txn.Set([]byte(key), data)
	})

	if err != nil {
		return utils.FailedBoolResult(err)
	}

	return utils.SuccessResult(true)
}

func (c *Cache) GetSubscription(externalID, organizationID string) utils.Result[*models.Subscription] {
	key := c.buildSubscriptionKey(externalID, organizationID)

	var sub models.Subscription
	err := c.db.View(func(txn *badger.Txn) error {
		item, err := txn.Get([]byte(key))
		if err != nil {
			return err
		}

		return item.Value(func(val []byte) error {
			return json.Unmarshal(val, &sub)
		})
	})

	if err == badger.ErrKeyNotFound {
		return utils.FailedResult[*models.Subscription](err).NonCapturable().NonRetryable()
	}

	if err != nil {
		return utils.FailedResult[*models.Subscription](err)
	}

	return utils.SuccessResult(&sub)
}

func (c *Cache) LoadSubscriptionsSnapshot(db *gorm.DB) utils.Result[int] {
	c.logger.Info("Starting subscriptions snapshot load")
	startTime := time.Now()

	result := models.GetAllSubscriptions(db)
	if result.Failure() {
		return utils.FailedResult[int](result.Error())
	}

	subscriptions := result.Value()
	count := 0

	for _, sub := range subscriptions {
		setResult := c.SetSubscription(&sub)
		if setResult.Failure() {
			c.logger.Error(
				"Failed to cache subscriptions",
				slog.String("error", setResult.ErrorMsg()),
				slog.String("organization_id", *sub.OrganizationID),
				slog.String("external_id", sub.ExternalID),
			)
			utils.CaptureErrorResult(setResult)
			continue
		}
		count++
	}

	duration := time.Since(startTime)
	c.logger.Info(
		"Completed subscriptions snapshot load",
		slog.Int("count", count),
		slog.Int64("duration_ms", duration.Milliseconds()),
	)

	return utils.SuccessResult(count)
}

