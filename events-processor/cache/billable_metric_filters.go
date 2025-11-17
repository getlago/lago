package cache

import (
	"fmt"

	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/utils"
	"gorm.io/gorm"
)

const (
	billableMetricFilterPrefix = "bmf"
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

func (c *Cache) DeleteBillableMetricFilter(bmf *models.BillableMetricFilter) utils.Result[bool] {
	key := c.buildBillableMetricFilterKey(bmf.OrganizationID, bmf.BillableMetricID, bmf.ID)
	return delete(c, key)
}

func (c *Cache) LoadBillableMetricFiltersSnapshot(db *gorm.DB) utils.Result[int] {
	return LoadSnapshot(
		c,
		"billable_metric_filters",
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
