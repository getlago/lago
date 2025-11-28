package cache

import (
	"fmt"

	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/utils"
	"gorm.io/gorm"
)

const (
	chargeFilterValuePrefix = "cfv"
)

func (c *Cache) buildChargeFilterValueKey(organizationID, chargeFilterID, billableMetricFilterID, id string) string {
	return fmt.Sprintf("%s:%s:%s:%s:%s", chargeFilterValuePrefix, organizationID, chargeFilterID, billableMetricFilterID, id)
}

func (c *Cache) SetChargeFilterValue(cfv *models.ChargeFilterValue) utils.Result[bool] {
	key := c.buildChargeFilterValueKey(cfv.OrganizationID, cfv.ChargeFilterID, cfv.BillableMetricFilterID, cfv.ID)
	return setJSON(c, key, cfv)
}

func (c *Cache) GetChargeFilterValue(organizationID, chargeFilterID, billableMetricFilterID, id string) utils.Result[*models.ChargeFilterValue] {
	key := c.buildChargeFilterValueKey(organizationID, chargeFilterID, billableMetricFilterID, id)
	return getJSON[models.ChargeFilterValue](c, key)
}

func (c *Cache) SearchChargeFilterValue(organizationID, chargeFilterID string) utils.Result[[]*models.ChargeFilterValue] {
	key := fmt.Sprintf("%s:%s:%s:", chargeFilterValuePrefix, organizationID, chargeFilterID)
	return searchJSON[models.ChargeFilterValue](c, key)
}

func (c *Cache) DeleteChargeFilterValue(cfv *models.ChargeFilterValue) utils.Result[bool] {
	key := c.buildChargeFilterValueKey(cfv.OrganizationID, cfv.ChargeFilterID, cfv.BillableMetricFilterID, cfv.ID)
	return delete(c, key)
}

func (c *Cache) LoadChargeFilterValuesSnapshot(db *gorm.DB) utils.Result[int] {
	return LoadSnapshot(
		c,
		"charge_filter_values",
		func() ([]models.ChargeFilterValue, error) {
			res := models.GetAllChargeFilterValues(db)
			if res.Failure() {
				return nil, res.Error()
			}
			return res.Value(), nil
		},
		func(cfv *models.ChargeFilterValue) string {
			return c.buildChargeFilterValueKey(cfv.OrganizationID, cfv.ChargeFilterID, cfv.BillableMetricFilterID, cfv.ID)
		},
	)
}
