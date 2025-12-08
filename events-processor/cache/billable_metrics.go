package cache

import (
	"context"
	"fmt"

	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/utils"
	"gorm.io/gorm"
)

const (
	billableMetricPrefix    = "bm"
	billableMetricModelName = "billable_metrics"
	billableMetricTopic     = ".public.billable_metrics"
)

func (c *Cache) buildBillableMetricKey(organizationID, code string) string {
	return fmt.Sprintf("%s:%s:%s", billableMetricPrefix, organizationID, code)
}

func (c *Cache) SetBillableMetric(bm *models.BillableMetric) utils.Result[bool] {
	key := c.buildBillableMetricKey(bm.OrganizationID, bm.Code)
	return setJSON(c, key, bm)
}

func (c *Cache) GetBillableMetric(organizationID, code string) utils.Result[*models.BillableMetric] {
	key := c.buildBillableMetricKey(organizationID, code)
	return getJSON[models.BillableMetric](c, key)
}

func (c *Cache) DeleteBillableMetric(bm *models.BillableMetric) utils.Result[bool] {
	key := c.buildBillableMetricKey(bm.OrganizationID, bm.Code)
	return delete(c, key)
}

func (c *Cache) LoadBillableMetricsSnapshot(db *gorm.DB) utils.Result[int] {
	return LoadSnapshot(
		c,
		billableMetricModelName,
		func() ([]models.BillableMetric, error) {
			res := models.GetAllBillableMetrics(db)
			if res.Failure() {
				return nil, res.Error()
			}
			return res.Value(), nil
		},
		func(bm *models.BillableMetric) string {
			return c.buildBillableMetricKey(bm.OrganizationID, bm.Code)
		},
	)
}

func (c *Cache) StartBillableMetricsConsumer(ctx context.Context) error {
	return startGenericConsumer(ctx, c, ConsumerConfig[models.BillableMetric]{
		Topic:     c.debeziumTopicPrefix + billableMetricTopic,
		ModelName: billableMetricModelName,
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
			return bm.UpdatedAt.Time.UnixMilli()
		},
		GetCached: func(bm *models.BillableMetric) utils.Result[*models.BillableMetric] {
			return c.GetBillableMetric(bm.OrganizationID, bm.Code)
		},
		SetCache: func(bm *models.BillableMetric) utils.Result[bool] {
			return c.SetBillableMetric(bm)
		},
		Delete: func(bm *models.BillableMetric) utils.Result[bool] {
			return c.DeleteBillableMetric(bm)
		},
	})
}
