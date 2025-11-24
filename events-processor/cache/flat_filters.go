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

// - BillableMetric
// - BillableMetricFilters
// - Charge
// - ChargeFilters
// - ChargeFilterValues
// SELECT
//   billable_metrics.organization_id AS organization_id,
//   billable_metrics.code AS billable_metric_code,
//   charges.plan_id AS plan_id,
//   charges.id AS charge_id,
//   charges.updated_at AS charge_updated_at,
//   charge_filters.id AS charge_filter_id,
//   charge_filters.updated_at AS charge_filter_updated_at,
//   CASE WHEN charge_filters.id IS NOT NULL
//   THEN
// 	  jsonb_object_agg(
// 	    COALESCE(billable_metric_filters.key, ''),
// 	    CASE
// 	      WHEN charge_filter_values.values::text[] && ARRAY['__ALL_FILTER_VALUES__']
// 	      THEN billable_metric_filters.values
// 	      ELSE charge_filter_values.values
// 	    end
// 	  ) [{"key": [""], "key": [""]}]
// 	  ELSE NULL
//   END AS filters,
//   COALESCE(charge_filters.properties, charges.properties) AS properties,
//   COALESCE(charge_filters.properties, charges.properties)->'pricing_group_keys' AS pricing_group_keys,
//   charges.pay_in_advance AS pay_in_advance
// FROM billable_metrics
//   INNER JOIN charges ON charges.billable_metric_id = billable_metrics.id
//   LEFT JOIN charge_filters ON charge_filters.charge_id = charges.id
//   LEFT JOIN charge_filter_values ON charge_filter_values.charge_filter_id = charge_filters.id
//   LEFT JOIN billable_metric_filters ON billable_metric_filters.id = charge_filter_values.billable_metric_filter_id
// WHERE
//   billable_metrics.deleted_at IS NULL
//   AND charges.deleted_at IS NULL
//   AND charge_filters.deleted_at IS NULL
//   AND charge_filter_values.deleted_at IS NULL
//   AND billable_metric_filters.deleted_at IS NULL
// GROUP BY
//   billable_metrics.organization_id,
//   billable_metrics.code,
//   charges.plan_id,
//   charges.id,
//   charges.updated_at,
//   charge_filters.id,
//   charge_filters.updated_at
