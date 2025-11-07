package cache

import (
	"context"
	"encoding/json"
	"log/slog"

	"github.com/dgraph-io/badger/v4"
	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/utils"
	"github.com/twmb/franz-go/pkg/kgo"
)

func (c *Cache) StartSubscriptionsConsumer(ctx context.Context) error {
	return startGenericConsumer(ctx, c, ConsumerConfig[models.Subscription]{
		Topic: "lago_proc_cdc.public.subscriptions",
		ModelName: "subscription",
		IsDeleted: func(sub *models.Subscription) bool {
			return sub.TerminatedAt.Valid
		},
		GetKey: func(sub *models.Subscription) string {
			return c.buildSubscriptionKey(sub.ExternalID, *sub.OrganizationID)
		},
		GetID: func(sub *models.Subscription) string {
			return sub.ID
		},
		GetUpdatedAt: func(sub *models.Subscription) int64 {
			return sub.UpdatedAt.UnixMilli()
		},
		GetCached: func(sub *models.Subscription) utils.Result[*models.Subscription] {
			return c.GetSubscription(sub.ExternalID, *sub.OrganizationID)
		},
		SetCache: func(sub *models.Subscription) utils.Result[bool] {
			return c.SetSubscription(sub)
		},
	})
	// topic := "lago_proc_cdc.public.subscriptions"
	// groupID := fmt.Sprintf("lago-evt-proc-che-subscriptions-%s", uuid.New().String())

	// client, err := kgo.NewClient(
	// 	kgo.SeedBrokers("redpanda:9092"),
	// 	kgo.ConsumerGroup(groupID),
	// 	kgo.ConsumeTopics(topic),
	// 	kgo.DisableAutoCommit(),
	// )
	// if err != nil {
	// 	return err
	// }

	// c.logger.Info(
	// 	"Starting subscriptions consumer",
	// 	slog.String("topic", topic),
	// 	slog.String("group_id", groupID),
	// )

	// c.wg.Add(1)
	// go func() {
	// 	defer c.wg.Done()
	// 	defer client.Close()

	// 	for {
	// 		select {
	// 		case <-ctx.Done():
	// 			c.logger.Info("Context canceled, stopping subscriptions consumer")
	// 			return
	// 		default:
	// 		}

	// 		fetches := client.PollFetches(ctx)
	// 		if fetches.IsClientClosed() {
	// 			c.logger.Info("Subscriptions consumer closed")
	// 			return
	// 		}

	// 		if err := fetches.Err(); err != nil {
	// 			c.logger.Error("Fetch error", slog.String("error", err.Error()))
	// 			utils.CaptureError(err)
	// 			continue
	// 		}

	// 		fetches.EachRecord(func(record *kgo.Record) {
	// 			c.processSubscriptionRecord(record)
	// 		})

	// 		client.CommitUncommittedOffsets(ctx)
	// 	}
	// }()

	// return nil
}

func (c *Cache) processSubscriptionRecord(record *kgo.Record) {
	var sub models.Subscription
	if err := json.Unmarshal(record.Value, &sub); err != nil {
		c.logger.Error(
			"Failed to unmarshal subscription",
			slog.String("error", err.Error()),
			slog.String("topic", record.Topic),
		)
		utils.CaptureError(err)
		return
	}

	if sub.TerminatedAt.Valid {
		existingRes := c.GetSubscription(sub.ExternalID, *sub.OrganizationID)
		if existingRes.Failure() {
			return
		}

		existing := existingRes.Value()
		if existing.ID != sub.ID {
			return
		}

		key := c.buildSubscriptionKey(sub.ExternalID, *sub.OrganizationID)
		if err := c.db.Update(func(txn *badger.Txn) error {
			return txn.Delete([]byte(key))
		}); err != nil {
			c.logger.Error(
				"Failed to delete from cache",
				slog.String("model", "subscription"),
				slog.String("key", key),
				slog.String("error", err.Error()),
			)
			utils.CaptureError(err)
		} else {
			c.logger.Debug(
				"Cache entry deleted",
				slog.String("organization_id", *sub.OrganizationID),
				slog.String("external_id", sub.ExternalID),
			)
		}

		return
	}

	existingRes := c.GetSubscription(sub.ExternalID, *sub.OrganizationID)
	if existingRes.Success() {
		existing := existingRes.Value()
		existingUpdatedAtMs := existing.UpdatedAt.UnixMilli()
		subUpdatedAtMs := sub.UpdatedAt.UnixMilli()
		if existingUpdatedAtMs >= subUpdatedAtMs {
			c.logger.Debug(
				"Skipping update - cached version newer",
				slog.String("organization_id", *sub.OrganizationID),
				slog.String("external_id", sub.ExternalID),
				slog.String("cached_updated_at", existing.UpdatedAt.String()),
				slog.String("message_updated_at", sub.UpdatedAt.String()),
			)
			return
		}
	}

	res := c.SetSubscription(&sub)
	if res.Failure() {
		c.logger.Error(
			"Failed to update cache from stream",
			slog.String("organization_id", *sub.OrganizationID),
			slog.String("external_id", sub.ExternalID),
			slog.String("error", res.ErrorMsg()),
		)
		utils.CaptureErrorResult(res)
	} else {
		c.logger.Debug(
			"Cache updated from stream",
			slog.String("model", "subscription"),
			slog.String("organization_id", *sub.OrganizationID),
			slog.String("external_id", sub.ExternalID),
			slog.String("updated_at", sub.UpdatedAt.String()),
		)
	}
}