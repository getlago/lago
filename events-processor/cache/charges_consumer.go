package cache

import (
	"context"

	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/utils"
)

func (c *Cache) StartChargesConsumer(ctx context.Context) error {
	return startGenericConsumer(ctx, c, ConsumerConfig[models.Charge]{
		Topic:     "lago_proc_cdc.public.charges",
		ModelName: "charge",
		IsDeleted: func(ch *models.Charge) bool {
			return ch.DeletedAt.Valid
		},
		GetKey: func(ch *models.Charge) string {
			return c.buildChargeKey(ch.OrganizationID, ch.PlanID, ch.BillableMetricID, ch.ID)
		},
		GetID: func(ch *models.Charge) string {
			return ch.ID
		},
		GetUpdatedAt: func(ch *models.Charge) int64 {
			return ch.UpdatedAt.Time.UnixMilli()
		},
		GetCached: func(ch *models.Charge) utils.Result[*models.Charge] {
			return c.GetCharge(ch.OrganizationID, ch.PlanID, ch.BillableMetricID, ch.ID)
		},
		SetCache: func(ch *models.Charge) utils.Result[bool] {
			return c.SetCharge(ch)
		},
		Delete: func(ch *models.Charge) utils.Result[bool] {
			return c.DeleteCharge(ch)
		},
	})
}
