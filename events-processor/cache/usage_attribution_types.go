package cache

import (
	"context"
	"fmt"

	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/utils"
	"gorm.io/gorm"
)

const (
	usageAttributionTypePrefix    = "uat"
	usageAttributionTypeModelName = "usage_attribution_types"
	usageAttributionTypeTopic     = ".public.usage_attribution_types"
)

func (c *Cache) buildUsageAttributionTypeKey(organizationID, id string) string {
	return fmt.Sprintf("%s:%s:%s", usageAttributionTypePrefix, organizationID, id)
}

func (c *Cache) SetUsageAttributionType(uat *models.UsageAttributionType) utils.Result[bool] {
	key := c.buildUsageAttributionTypeKey(uat.OrganizationID, uat.ID)
	return setJSON(c, key, uat)
}

func (c *Cache) GetUsageAttributionType(organizationID, id string) utils.Result[*models.UsageAttributionType] {
	key := c.buildUsageAttributionTypeKey(organizationID, id)
	return getJSON[models.UsageAttributionType](c, key)
}

func (c *Cache) SearchUsageAttributionTypes(organizationID string) utils.Result[[]*models.UsageAttributionType] {
	prefix := fmt.Sprintf("%s:%s:", usageAttributionTypePrefix, organizationID)
	return searchJSON[models.UsageAttributionType](c, prefix)
}

func (c *Cache) DeleteUsageAttributionType(uat *models.UsageAttributionType) utils.Result[bool] {
	key := c.buildUsageAttributionTypeKey(uat.OrganizationID, uat.ID)
	return delete(c, key)
}

func (c *Cache) LoadUsageAttributionTypesSnapshot(db *gorm.DB) utils.Result[int] {
	return LoadSnapshot(
		c,
		usageAttributionTypeModelName,
		func() ([]models.UsageAttributionType, error) {
			res := models.GetAllUsageAttributionTypes(db)
			if res.Failure() {
				return nil, res.Error()
			}
			return res.Value(), nil
		},
		func(uat *models.UsageAttributionType) string {
			return c.buildUsageAttributionTypeKey(uat.OrganizationID, uat.ID)
		},
	)
}

func (c *Cache) StartUsageAttributionTypesConsumer(ctx context.Context) error {
	return startGenericConsumer(ctx, c, ConsumerConfig[models.UsageAttributionType]{
		Topic:     c.debeziumTopicPrefix + usageAttributionTypeTopic,
		ModelName: usageAttributionTypeModelName,
		IsDeleted: func(uat *models.UsageAttributionType) bool {
			return uat.DeletedAt.Valid
		},
		GetKey: func(uat *models.UsageAttributionType) string {
			return c.buildUsageAttributionTypeKey(uat.OrganizationID, uat.ID)
		},
		GetID: func(uat *models.UsageAttributionType) string {
			return uat.ID
		},
		GetUpdatedAt: func(uat *models.UsageAttributionType) int64 {
			return uat.UpdatedAt.Time.UnixMilli()
		},
		GetCached: func(uat *models.UsageAttributionType) utils.Result[*models.UsageAttributionType] {
			return c.GetUsageAttributionType(uat.OrganizationID, uat.ID)
		},
		SetCache: func(uat *models.UsageAttributionType) utils.Result[bool] {
			return c.SetUsageAttributionType(uat)
		},
		Delete: func(uat *models.UsageAttributionType) utils.Result[bool] {
			return c.DeleteUsageAttributionType(uat)
		},
	})
}
