package cache

import (
	"context"

	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/utils"
)

func (c *Cache) StartBillableMetricsConsumer(ctx context.Context) error {
	return startGenericConsumer(ctx, c, ConsumerConfig[models.BillableMetric]{
		Topic:     "lago_proc_cdc.public.billable_metrics",
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
