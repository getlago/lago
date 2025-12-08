package cache

import (
	"context"
	"fmt"

	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/utils"
	"gorm.io/gorm"
)

const (
	chargeFilterValuePrefix    = "cfv"
	chargeFilterValueModelName = "charge_filter_values"
	chargeFilterValueTopic     = ".public.charge_filter_values"
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
		chargeFilterValueModelName,
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

func (c *Cache) StartChargeFilterValuesConsumer(ctx context.Context) error {
	return startGenericConsumer(ctx, c, ConsumerConfig[models.ChargeFilterValue]{
		Topic:     c.debeziumTopicPrefix + chargeFilterValueTopic,
		ModelName: chargeFilterValueModelName,
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
