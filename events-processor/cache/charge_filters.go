package cache

import (
	"fmt"

	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/utils"
	"gorm.io/gorm"
)

const (
	chargeFilterPrefix = "cf"
)

func (c *Cache) buildChargeFilterKey(organizationID, chargeID, id string) string {
	return fmt.Sprintf("%s:%s:%s:%s", chargeFilterPrefix, organizationID, chargeID, id)
}

func (c *Cache) SetChargeFilter(cf *models.ChargeFilter) utils.Result[bool] {
	key := c.buildChargeFilterKey(cf.OrganizationID, cf.ChargeID, cf.ID)
	return setJSON(c, key, cf)
}

func (c *Cache) GetChargeFilter(organizationID, chargeID, id string) utils.Result[*models.ChargeFilter] {
	key := c.buildChargeFilterKey(organizationID, chargeID, id)
	return getJSON[models.ChargeFilter](c, key)
}

func (c *Cache) DeleteChargeFilter(cf *models.ChargeFilter) utils.Result[bool] {
	key := c.buildChargeFilterKey(cf.OrganizationID, cf.ChargeID, cf.ID)
	return delete(c, key)
}

func (c *Cache) LoadChargeFiltersSnapshot(db *gorm.DB) utils.Result[int] {
	return LoadSnapshot(
		c,
		"charge_filters",
		func() ([]models.ChargeFilter, error) {
			res := models.GetAllChargeFilters(db)
			if res.Failure() {
				return nil, res.Error()
			}
			return res.Value(), nil
		},
		func(cf *models.ChargeFilter) string {
			return c.buildChargeFilterKey(cf.OrganizationID, cf.ChargeID, cf.ID)
		},
	)
}
