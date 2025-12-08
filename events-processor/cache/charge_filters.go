package cache

import (
	"context"
	"fmt"

	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/utils"
	"gorm.io/gorm"
)

const (
	chargeFilterPrefix    = "cf"
	chargeFilterModelName = "charge_filters"
	chargeFilterTopic     = ".public.charge_filters"
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

func (c *Cache) SearchChargeFilter(organizationID, chargeID string) utils.Result[[]*models.ChargeFilter] {
	key := fmt.Sprintf("%s:%s:%s:", chargeFilterPrefix, organizationID, chargeID)
	return searchJSON[models.ChargeFilter](c, key)
}

func (c *Cache) DeleteChargeFilter(cf *models.ChargeFilter) utils.Result[bool] {
	key := c.buildChargeFilterKey(cf.OrganizationID, cf.ChargeID, cf.ID)
	return delete(c, key)
}

func (c *Cache) LoadChargeFiltersSnapshot(db *gorm.DB) utils.Result[int] {
	return LoadSnapshot(
		c,
		chargeFilterModelName,
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

func (c *Cache) StartChargeFiltersConsumer(ctx context.Context) error {
	return startGenericConsumer(ctx, c, ConsumerConfig[models.ChargeFilter]{
		Topic:     c.debeziumTopicPrefix + chargeFilterTopic,
		ModelName: chargeFilterModelName,
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
