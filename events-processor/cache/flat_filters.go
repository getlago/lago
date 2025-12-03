package cache

import (
	"slices"

	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/utils"
)

func (c *Cache) BuildFlatFilters(organizationID, billableMetricCode, planID string) utils.Result[[]*models.FlatFilter] {
	var flatFilters []*models.FlatFilter

	bmResult := c.GetBillableMetric(organizationID, billableMetricCode)
	if bmResult.Failure() {
		return utils.FailedResult[[]*models.FlatFilter](bmResult.Error())
	}
	billableMetric := bmResult.Value()

	bmfResult := c.SearchBillableMetricFilters(organizationID, billableMetric.ID)
	if bmfResult.Failure() {
		return utils.FailedResult[[]*models.FlatFilter](bmfResult.Error())
	}
	billableMetricFilters := bmfResult.Value()

	bmFilterMap := make(map[string]*models.BillableMetricFilter)
	for _, bmf := range billableMetricFilters {
		bmFilterMap[bmf.ID] = bmf
	}

	chResult := c.SearchCharge(organizationID, planID, billableMetric.ID)
	if chResult.Failure() {
		return utils.FailedResult[[]*models.FlatFilter](chResult.Error())
	}
	charges := chResult.Value()

	for _, charge := range charges {
		chfResult := c.SearchChargeFilter(organizationID, charge.ID)
		if chfResult.Failure() {
			return utils.FailedResult[[]*models.FlatFilter](chfResult.Error())
		}
		chargeFilters := chfResult.Value()

		if len(chargeFilters) == 0 {
			flatFilter := &models.FlatFilter{
				OrganizationID:        organizationID,
				BillableMetricCode:    billableMetricCode,
				PlanID:                planID,
				ChargeID:              charge.ID,
				ChargeUpdatedAt:       charge.UpdatedAt.Time,
				ChargeFilterID:        nil,
				ChargeFilterUpdatedAt: nil,
				Filters:               nil,
				PricingGroupKeys:      models.PricingGroupKeys(charge.PricingGroupKeys),
				PayInAdvance:          charge.PayInAdvance,
			}
			flatFilters = append(flatFilters, flatFilter)
		} else {
			for _, chargeFilter := range chargeFilters {
				cfvResult := c.SearchChargeFilterValue(organizationID, chargeFilter.ID)
				if cfvResult.Failure() {
					return utils.FailedResult[[]*models.FlatFilter](cfvResult.Error())
				}
				chargeFilterValues := cfvResult.Value()

				filters := make(models.FlatFilterValues)
				for _, cfv := range chargeFilterValues {
					bmFilter, exists := bmFilterMap[cfv.BillableMetricFilterID]
					if !exists {
						continue
					}

					key := bmFilter.Key
					var values []string

					hasAllFilterValues := slices.Contains(cfv.Values, "__ALL_FILTER_VALUES__")
					if hasAllFilterValues {
						values = bmFilter.Values
					} else {
						values = cfv.Values
					}

					filters[key] = values
				}

				flatFilter := &models.FlatFilter{
					OrganizationID:        organizationID,
					BillableMetricCode:    billableMetricCode,
					PlanID:                planID,
					ChargeID:              charge.ID,
					ChargeUpdatedAt:       charge.UpdatedAt.Time,
					ChargeFilterID:        &chargeFilter.ID,
					ChargeFilterUpdatedAt: &chargeFilter.UpdatedAt.Time,
					Filters:               &filters,
					PricingGroupKeys:      models.PricingGroupKeys(chargeFilter.PricingGroupKeys),
					PayInAdvance:          charge.PayInAdvance,
				}
				flatFilters = append(flatFilters, flatFilter)
			}
		}
	}

	return utils.SuccessResult(flatFilters)
}
