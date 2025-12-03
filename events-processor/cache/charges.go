package cache

import (
	"fmt"

	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/utils"
	"gorm.io/gorm"
)

const (
	chargePrefix = "ch"
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
		"charges",
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
