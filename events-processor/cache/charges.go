package cache

import (
	"context"
	"fmt"

	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/utils"
	"gorm.io/gorm"
)

const (
	chargePrefix    = "ch"
	chargeModelName = "charges"
	chargeTopic     = ".public.charges"
)

func (c *Cache) buildChargeKey(organizationID, planID, billableMetricID, id string) string {
	return fmt.Sprintf("%s:%s:%s:%s:%s", chargePrefix, organizationID, planID, billableMetricID, id)
}

func (c *Cache) SetCharge(ch *models.Charge) utils.Result[bool] {
	key := c.buildChargeKey(ch.OrganizationID, ch.PlanID, ch.BillableMetricID, ch.ID)
	return setJSON(c, key, ch)
}

func (c *Cache) GetCharge(organizationID, planID, billableMetricID, id string) utils.Result[*models.Charge] {
	key := c.buildChargeKey(organizationID, planID, billableMetricID, id)
	return getJSON[models.Charge](c, key)
}

func (c *Cache) SearchCharge(organizationID, planID, billableMetricID string) utils.Result[[]*models.Charge] {
	key := fmt.Sprintf("%s:%s:%s:%s:", chargePrefix, organizationID, planID, billableMetricID)
	return searchJSON[models.Charge](c, key)
}

func (c *Cache) DeleteCharge(ch *models.Charge) utils.Result[bool] {
	key := c.buildChargeKey(ch.OrganizationID, ch.PlanID, ch.BillableMetricID, ch.ID)
	return delete(c, key)
}

func (c *Cache) LoadChargesSnapshot(db *gorm.DB) utils.Result[int] {
	return LoadSnapshot(
		c,
		chargeModelName,
		func() ([]models.Charge, error) {
			res := models.GetAllCharges(db)
			if res.Failure() {
				return nil, res.Error()
			}
			return res.Value(), nil
		},
		func(ch *models.Charge) string {
			return c.buildChargeKey(ch.OrganizationID, ch.PlanID, ch.BillableMetricID, ch.ID)
		},
	)
}

func (c *Cache) StartChargesConsumer(ctx context.Context) error {
	return startGenericConsumer(ctx, c, ConsumerConfig[models.Charge]{
		Topic:     c.debeziumTopicPrefix + chargeTopic,
		ModelName: chargeModelName,
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
