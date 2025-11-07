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

func (c *Cache) StartBillableMetricsConsumer(ctx context.Context) error {
	return startGenericConsumer(ctx, c, ConsumerConfig[models.BillableMetric]{
		Topic: "lago_proc_cdc.public.billable_metrics",
		ModelName: "billable_metric",
		IsDeleted: func(bm *models.BillableMetric) bool {
			return bm.DeletedAt.Valid
		},
		GetKey: func(bm *models.BillableMetric) string {
			return c.buildBillableMetricKey(bm.OrganizationID, bm.Code)
		},
		GetID: func(bm *models.BillableMetric) string {
			return bm.ID
		},
		GetUpdatedAt: func(bm *models.BillableMetric) int64 {
			return bm.UpdatedAt.UnixMilli()
		},
		GetCached: func(bm *models.BillableMetric) utils.Result[*models.BillableMetric] {
			return c.GetBillableMetric(bm.OrganizationID, bm.Code)
		},
		SetCache: func(bm *models.BillableMetric) utils.Result[bool] {
			return c.SetBillableMetric(bm)
		},
	})
	// topic := "lago_proc_cdc.public.billable_metrics"
	// groupID := fmt.Sprintf("lago-evt-proc-che-billable-metrics-%s", uuid.New().String())

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
	// 	"Starting billable metrics consumer",
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
	// 			c.logger.Info("Context canceled, stopping billable metrics consumer")
	// 			return
	// 		default:
	// 		}

	// 		fetches := client.PollFetches(ctx)
	// 		if fetches.IsClientClosed() {
	// 			c.logger.Info("Billable metrics consumer closed")
	// 			return
	// 		}

	// 		if err := fetches.Err(); err != nil {
	// 			c.logger.Error("Fetch error", slog.String("error", err.Error()))
	// 			utils.CaptureError(err)
	// 			continue
	// 		}

	// 		fetches.EachRecord(func(record *kgo.Record) {
	// 			c.processBillableMetricRecord(record)
	// 		})

	// 		client.CommitUncommittedOffsets(ctx)
	// 	}
	// }()

	// return nil
}

func (c *Cache) processBillableMetricRecord(record *kgo.Record) {
	var bm models.BillableMetric
	if err := json.Unmarshal(record.Value, &bm); err != nil {
		c.logger.Error(
			"Failed to unmarshal billable metric",
			slog.String("error", err.Error()),
			slog.String("topic", record.Topic),
		)
		utils.CaptureError(err)
		return
	}

	if bm.DeletedAt.Valid {
		existingRes := c.GetBillableMetric(bm.OrganizationID, bm.Code)
		if existingRes.Failure() {
			return
		}

		existing := existingRes.Value()
		if existing.ID != bm.ID {
			return
		}

		key := c.buildBillableMetricKey(bm.OrganizationID, bm.Code)
		if err := c.db.Update(func(txn *badger.Txn) error {
			return txn.Delete([]byte(key))
		}); err != nil {
			c.logger.Error(
				"Failed to delete from cache",
				slog.String("model", "billable_metric"),
				slog.String("key", key),
				slog.String("error", err.Error()),
			)
			utils.CaptureError(err)
		} else {
			c.logger.Debug(
				"Cache entry deleted",
				slog.String("organization_id", bm.OrganizationID),
				slog.String("code", bm.Code),
			)
		}

		return
	}

	existingRes := c.GetBillableMetric(bm.OrganizationID, bm.Code)
	if existingRes.Success() {
		existing := existingRes.Value()
		existingUpdatedAtMs := existing.UpdatedAt.UnixMilli()
		bmUpdatedAtMs := bm.UpdatedAt.UnixMilli()
		if existingUpdatedAtMs >= bmUpdatedAtMs {
			c.logger.Debug(
				"Skipping update - cached version newer",
				slog.String("organization_id", bm.OrganizationID),
				slog.String("code", bm.Code),
				slog.String("cached_updated_at", existing.UpdatedAt.String()),
				slog.String("message_updated_at", bm.UpdatedAt.String()),
			)
			return
		}
	}

	res := c.SetBillableMetric(&bm)
	if res.Failure() {
		c.logger.Error(
			"Failed to update cache from stream",
			slog.String("organization_id", bm.OrganizationID),
			slog.String("code", bm.Code),
			slog.String("error", res.ErrorMsg()),
		)
		utils.CaptureErrorResult(res)
	} else {
		c.logger.Debug(
			"Cache updated from stream",
			slog.String("model", "billable_metric"),
			slog.String("organization_id", bm.OrganizationID),
			slog.String("code", bm.Code),
			slog.String("updated_at", bm.UpdatedAt.String()),
		)
	}
}