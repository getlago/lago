package cache

import (
	"context"
	"fmt"

	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/utils"
	"gorm.io/gorm"
)

const (
	billableMetricFilterPrefix    = "bmf"
	billableMetricFilterModelName = "billable_metric_filters"
	billableMetricFilterTopic     = ".public.billable_metric_filters"
)

func (c *Cache) buildBillableMetricFilterKey(organizationID, billableMetricID, id string) string {
	return fmt.Sprintf("%s:%s:%s:%s", billableMetricFilterPrefix, organizationID, billableMetricID, id)
}

func (c *Cache) SetBillableMetricFilter(bmf *models.BillableMetricFilter) utils.Result[bool] {
	key := c.buildBillableMetricFilterKey(bmf.OrganizationID, bmf.BillableMetricID, bmf.ID)
	return setJSON(c, key, bmf)
}

func (c *Cache) GetBillableMetricFilter(organizationID, billableMetricID, id string) utils.Result[*models.BillableMetricFilter] {
	key := c.buildBillableMetricFilterKey(organizationID, billableMetricID, id)
	return getJSON[models.BillableMetricFilter](c, key)
}

func (c *Cache) SearchBillableMetricFilters(organizationID, billableMetricID string) utils.Result[[]*models.BillableMetricFilter] {
	prefix := fmt.Sprintf("%s:%s:%s:", billableMetricFilterPrefix, organizationID, billableMetricID)

	return searchJSON[models.BillableMetricFilter](c, prefix)
}

func (c *Cache) DeleteBillableMetricFilter(bmf *models.BillableMetricFilter) utils.Result[bool] {
	key := c.buildBillableMetricFilterKey(bmf.OrganizationID, bmf.BillableMetricID, bmf.ID)
	return delete(c, key)
}

func (c *Cache) LoadBillableMetricFiltersSnapshot(db *gorm.DB) utils.Result[int] {
	return LoadSnapshot(
		c,
		billableMetricFilterModelName,
		func() ([]models.BillableMetricFilter, error) {
			res := models.GetAllBillableMetricFilters(db)
			if res.Failure() {
				return nil, res.Error()
			}
			return res.Value(), nil
		},
		func(bmf *models.BillableMetricFilter) string {
			return c.buildBillableMetricFilterKey(bmf.OrganizationID, bmf.BillableMetricID, bmf.ID)
		},
	)
}

func (c *Cache) StartBillableMetricFiltersConsumer(ctx context.Context) error {
	return startGenericConsumer(ctx, c, ConsumerConfig[models.BillableMetricFilter]{
		Topic:     c.debeziumTopicPrefix + billableMetricFilterTopic,
		ModelName: billableMetricFilterModelName,
		IsDeleted: func(bmf *models.BillableMetricFilter) bool {
			return bmf.DeletedAt.Valid
		},
		GetKey: func(bmf *models.BillableMetricFilter) string {
			return c.buildBillableMetricFilterKey(bmf.OrganizationID, bmf.BillableMetricID, bmf.ID)
		},
		GetID: func(bmf *models.BillableMetricFilter) string {
			return bmf.ID
		},
		GetUpdatedAt: func(bmf *models.BillableMetricFilter) int64 {
			return bmf.UpdatedAt.Time.UnixMilli()
		},
		GetCached: func(bmf *models.BillableMetricFilter) utils.Result[*models.BillableMetricFilter] {
			return c.GetBillableMetricFilter(bmf.OrganizationID, bmf.BillableMetricID, bmf.ID)
		},
		SetCache: func(bmf *models.BillableMetricFilter) utils.Result[bool] {
			return c.SetBillableMetricFilter(bmf)
		},
		Delete: func(bmf *models.BillableMetricFilter) utils.Result[bool] {
			return c.DeleteBillableMetricFilter(bmf)
		},
	})
}
