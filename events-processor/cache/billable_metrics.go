package cache

import (
	"fmt"

	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/utils"
	"gorm.io/gorm"
)

const (
	billableMetricPrefix = "bm"
)

func (c *Cache) buildBillableMetricKey(organizationID, code string) string {
	return fmt.Sprintf("%s:%s:%s", billableMetricPrefix, organizationID, code)
}

func (c *Cache) SetBillableMetric(bm *models.BillableMetric) utils.Result[bool] {
	key := c.buildBillableMetricKey(bm.OrganizationID, bm.Code)
	return setJSON(c, key, bm)
}

func (c *Cache) GetBillableMetric(organizationID, code string) utils.Result[*models.BillableMetric] {
	key := c.buildBillableMetricKey(organizationID, code)
	return getJSON[models.BillableMetric](c, key)
}

func (c *Cache) DeleteBillableMetric(bm *models.BillableMetric) utils.Result[bool] {
	key := c.buildBillableMetricKey(bm.OrganizationID, bm.Code)
	return delete(c, key)
}

func (c *Cache) LoadBillableMetricsSnapshot(db *gorm.DB) utils.Result[int] {
	return LoadSnapshot(
		c,
		"billable_metrics",
		func() ([]models.BillableMetric, error) {
			res := models.GetAllBillableMetrics(db)
			if res.Failure() {
				return nil, res.Error()
			}
			return res.Value(), nil
		},
		func(bm *models.BillableMetric) string {
			return c.buildBillableMetricKey(bm.OrganizationID, bm.Code)
		},
	)
}
