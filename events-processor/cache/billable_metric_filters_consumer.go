package cache

import (
	"context"

	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/utils"
)

func (c *Cache) StartBillableMetricFiltersConsumer(ctx context.Context) error {
	return startGenericConsumer(ctx, c, ConsumerConfig[models.BillableMetricFilter]{
		Topic:     "lago_proc_cdc.public.billable_metric_filters",
		ModelName: "billable_metric_filters",
		IsDeleted: func(bmf *models.BillableMetricFilter) bool {
			return bmf.DeletedAt.Valid
		},
		GetKey: func(bmf *models.BillableMetricFilter) string {
			return c.buildBillableMetricFilterKey(bmf.OrganizationID, bmf.BillableMetricID, bmf.ID)
		},
		GetID: func(bmf *models.BillableMetricFilter) string {
			return bmf.ID
		},
		GetUpdatedAt: func(bmf *models.BillableMetricFilter) int64 {
			return bmf.UpdatedAt.Time.UnixMilli()
		},
		GetCached: func(bmf *models.BillableMetricFilter) utils.Result[*models.BillableMetricFilter] {
			return c.GetBillableMetricFilter(bmf.OrganizationID, bmf.BillableMetricID, bmf.ID)
		},
		SetCache: func(bmf *models.BillableMetricFilter) utils.Result[bool] {
			return c.SetBillableMetricFilter(bmf)
		},
		Delete: func(bmf *models.BillableMetricFilter) utils.Result[bool] {
			return c.DeleteBillableMetricFilter(bmf)
		},
	})
}
