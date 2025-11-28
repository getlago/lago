package cache

import (
	"context"

	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/utils"
)

func (c *Cache) StartChargeFilterValuesConsumer(ctx context.Context) error {
	return startGenericConsumer(ctx, c, ConsumerConfig[models.ChargeFilterValue]{
		Topic:     "lago_proc_cdc.public.charge_filter_values",
		ModelName: "charge_filter_value",
		IsDeleted: func(cfv *models.ChargeFilterValue) bool {
			return cfv.DeletedAt.Valid
		},
		GetKey: func(cfv *models.ChargeFilterValue) string {
			return c.buildChargeFilterValueKey(cfv.OrganizationID, cfv.ChargeFilterID, cfv.BillableMetricFilterID, cfv.ID)
		},
		GetID: func(cfv *models.ChargeFilterValue) string {
			return cfv.ID
		},
		GetUpdatedAt: func(cfv *models.ChargeFilterValue) int64 {
			return cfv.UpdatedAt.Time.UnixMilli()
		},
		GetCached: func(cfv *models.ChargeFilterValue) utils.Result[*models.ChargeFilterValue] {
			return c.GetChargeFilterValue(cfv.OrganizationID, cfv.ChargeFilterID, cfv.BillableMetricFilterID, cfv.ID)
		},
		SetCache: func(cfv *models.ChargeFilterValue) utils.Result[bool] {
			return c.SetChargeFilterValue(cfv)
		},
		Delete: func(cfv *models.ChargeFilterValue) utils.Result[bool] {
			return c.DeleteChargeFilterValue(cfv)
		},
	})
}
