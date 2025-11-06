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
	billableMetricPrefix = "bm"
)

func (c *Cache) buildBillableMetricKey(organizationID, code string) string {
	return fmt.Sprintf("%s:%s:%s", billableMetricPrefix, organizationID, code)
}

func (c *Cache) SetBillableMetric(bm *models.BillableMetric) utils.Result[bool] {
	key := c.buildBillableMetricKey(bm.OrganizationID, bm.Code)

	data, err := json.Marshal(bm)
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

func (c *Cache) GetBillableMetric(organizationID, code string) utils.Result[*models.BillableMetric] {
	key := c.buildBillableMetricKey(organizationID, code)

	var bm models.BillableMetric
	err := c.db.View(func(txn *badger.Txn) error {
		item, err := txn.Get([]byte(key))
		if err != nil {
			return err
		}

		return item.Value(func(val []byte) error {
			return json.Unmarshal(val, &bm)
		})
	})

	if err == badger.ErrKeyNotFound {
		return utils.FailedResult[*models.BillableMetric](err).NonCapturable().NonRetryable()
	}

	if err != nil {
		return utils.FailedResult[*models.BillableMetric](err)
	}

	return utils.SuccessResult(&bm)
}

func (c *Cache) LoadBillableMetricsSnapshot(db *gorm.DB) utils.Result[int] {
	c.logger.Info("Starting billable metrics snapshot load")
	startTime := time.Now()

	result := models.GetAllBillableMetrics(db)
	if result.Failure() {
		return utils.FailedResult[int](result.Error())
	}

	billableMetrics := result.Value()
	count := 0

	for _, bm := range billableMetrics {
		setResult := c.SetBillableMetric(&bm)
		if setResult.Failure() {
			c.logger.Error(
				"Failed to cache billable metric",
				slog.String("error", setResult.ErrorMsg()),
				slog.String("organization_id", bm.OrganizationID),
				slog.String("code", bm.Code),
			)
			utils.CaptureErrorResult(setResult)
			continue
		}
		count++
	}

	duration := time.Since(startTime)
	c.logger.Info(
		"Completed billable metrics snapshot load",
		slog.Int("count", count),
		slog.Int64("duration_ms", duration.Milliseconds()),
	)

	return utils.SuccessResult(count)
}