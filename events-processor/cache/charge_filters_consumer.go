package cache

import (
	"context"

	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/utils"
)

func (c *Cache) StartChargeFiltersConsumer(ctx context.Context) error {
	return startGenericConsumer(ctx, c, ConsumerConfig[models.ChargeFilter]{
		Topic:     "lago_proc_cdc.public.charge_filters",
		ModelName: "charge_filter",
		IsDeleted: func(cf *models.ChargeFilter) bool {
			return cf.DeletedAt.Valid
		},
		GetKey: func(cf *models.ChargeFilter) string {
			return c.buildChargeFilterKey(cf.OrganizationID, cf.ChargeID, cf.ID)
		},
		GetID: func(cf *models.ChargeFilter) string {
			return cf.ID
		},
		GetUpdatedAt: func(cf *models.ChargeFilter) int64 {
			return cf.UpdatedAt.Time.UnixMilli()
		},
		GetCached: func(cf *models.ChargeFilter) utils.Result[*models.ChargeFilter] {
			return c.GetChargeFilter(cf.OrganizationID, cf.ChargeID, cf.ID)
		},
		SetCache: func(cf *models.ChargeFilter) utils.Result[bool] {
			return c.SetChargeFilter(cf)
		},
		Delete: func(cf *models.ChargeFilter) utils.Result[bool] {
			return c.DeleteChargeFilter(cf)
		},
	})
}
