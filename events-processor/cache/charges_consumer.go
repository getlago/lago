package cache

import (
	"context"

	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/utils"
)

func (c *Cache) StartChargesConsumer(ctx context.Context) error {
	return startGenericConsumer(ctx, c, ConsumerConfig[models.Charge]{
		Topic:     "lago_prodc_cdc.public.charges",
		ModelName: "charge",
		IsDeleted: func(ch *models.Charge) bool {
			return ch.DeletedAt.Valid
		},
		GetKey: func(ch *models.Charge) string {
			return c.buildChargeKey(ch.OrganizationID, ch.PlanID, ch.BillableMetricID)
		},
		GetID: func(ch *models.Charge) string {
			return ch.ID
		},
		GetUpdatedAt: func(ch *models.Charge) int64 {
			return ch.UpdatedAt.Time.UnixMilli()
		},
		GetCached: func(ch *models.Charge) utils.Result[*models.Charge] {
			return c.GetCharge(ch.OrganizationID, ch.PlanID, ch.BillableMetricID)
		},
		SetCache: func(ch *models.Charge) utils.Result[bool] {
			return c.SetCharge(ch)
		},
	})
}
