package models

import (
	"database/sql/driver"
	"encoding/json"
	"fmt"
	"slices"
	"time"

	"github.com/getlago/lago/events-processor/utils"
)

type FlatFilterValues map[string][]string
type PricingGroupKeys []string

// Implements the sql.Scanner interface to convert JSONB into FlatFilterValues
func (fm *FlatFilterValues) Scan(value any) error {
	if value == nil {
		*fm = nil
		return nil
	}

	var bytes []byte
	switch v := value.(type) {
	case []byte:
		bytes = v
	case string:
		bytes = []byte(v)
	default:
		return fmt.Errorf("cannot scan %T into FlatFilterValues", value)
	}

	var result map[string][]string
	if err := json.Unmarshal(bytes, &result); err != nil {
		return err
	}

	*fm = FlatFilterValues(result)
	return nil
}

// Implements the driver.Valuer interface converting FlatFilterValues to a JSONB value
func (fm FlatFilterValues) Value() (driver.Value, error) {
	if fm == nil {
		return nil, nil
	}

	return json.Marshal(map[string][]string(fm))
}

// Implements the sql.Scanner interface to convert JSONB into FlatFilterValues
func (fm *PricingGroupKeys) Scan(value any) error {
	if value == nil {
		*fm = nil
		return nil
	}

	var bytes []byte
	switch v := value.(type) {
	case []byte:
		bytes = v
	case string:
		bytes = []byte(v)
	default:
		return fmt.Errorf("cannot scan %T into FlatFilterValues", value)
	}

	var result []string
	if err := json.Unmarshal(bytes, &result); err != nil {
		return err
	}

	*fm = PricingGroupKeys(result)
	return nil
}

// Implements the driver.Valuer interface converting FlatFilterValues to a JSONB value
func (fm PricingGroupKeys) Value() (driver.Value, error) {
	if fm == nil {
		return nil, nil
	}

	return json.Marshal([]string(fm))
}

type FlatFilter struct {
	OrganizationID        string            `gorm:"->"`
	BillableMetricCode    string            `gorm:"->"`
	PlanID                string            `gorm:"->"`
	ChargeID              string            `gorm:"->"`
	ChargeUpdatedAt       time.Time         `gorm:"->"`
	ChargeFilterID        *string           `gorm:"->"`
	ChargeFilterUpdatedAt *time.Time        `gorm:"->"`
	Filters               *FlatFilterValues `gorm:"type:jsonb"`
	PricingGroupKeys      PricingGroupKeys  `gorm:"type:jsonb"`
	PayInAdvance          bool              `gorm:"type:boolean"`
}

func (store *ApiStore) FetchFlatFilters(planID string, billableMetricCode string) utils.Result[[]FlatFilter] {
	var filters []FlatFilter

	result := store.db.Connection.Find(&filters, "plan_id = ? AND billable_metric_code = ?", planID, billableMetricCode)
	if result.Error != nil {
		return utils.FailedResult[[]FlatFilter](result.Error)
	}

	return utils.SuccessResult(filters)
}

func (ffv *FlatFilterValues) Keys() []string {
	if ffv == nil || *ffv == nil {
		return nil
	}

	keys := make([]string, len(*(ffv)))
	i := 0
	for key := range *(ffv) {
		keys[i] = key
		i++
	}

	return keys
}

func (ff *FlatFilter) HasFilters() bool {
	return ff.Filters != nil && len(*ff.Filters) > 0
}

func (ff *FlatFilter) IsMatchingEvent(event *EnrichedEvent) utils.Result[bool] {
	matching := true
	if !ff.HasFilters() {
		return utils.SuccessResult(matching)
	}

	for key, values := range *(ff.Filters) {
		if event.Properties[key] == nil {
			matching = false
			break
		}

		if !slices.Contains(values, fmt.Sprintf("%v", event.Properties[key])) {
			matching = false
			break
		}
	}

	return utils.SuccessResult(matching)
}

func (ff *FlatFilter) ToDefaultFilter() *FlatFilter {
	defaultFilter := &FlatFilter{
		OrganizationID:     ff.OrganizationID,
		BillableMetricCode: ff.BillableMetricCode,
		PlanID:             ff.PlanID,
		ChargeID:           ff.ChargeID,
		ChargeUpdatedAt:    ff.ChargeUpdatedAt,
		PayInAdvance:       ff.PayInAdvance,
	}

	return defaultFilter
}

func MatchingFilter(filters []FlatFilter, event *EnrichedEvent) *FlatFilter {
	// Multiple filters are present, identify the best match
	if len(filters) > 1 {
		// First select all matching filters
		matchingFilters := make([]FlatFilter, 0)
		for _, filter := range filters {
			if filter.HasFilters() && filter.IsMatchingEvent(event).Value() {
				matchingFilters = append(matchingFilters, filter)
			}
		}

		// No filters matches the event
		if len(matchingFilters) == 0 {
			// Return the charge's default bucket
			return filters[0].ToDefaultFilter()

		} else {
			// NOTE: Multiple filters match the event (parent/child filters),
			//       We must take only the one matching the most properties
			var bestFilter *FlatFilter
			for _, filter := range matchingFilters {
				if bestFilter == nil {
					bestFilter = &filter
					continue
				}

				if len(filter.Filters.Keys()) > len(bestFilter.Filters.Keys()) {
					bestFilter = &filter
				}
			}

			// Return the best match
			return bestFilter
		}

	} else {
		filter := filters[0]

		// Check if the only filter is matching the event
		if filter.HasFilters() && filter.IsMatchingEvent(event).Value() {
			// Return the only matching filter
			return &filter
		} else {
			// Otherwise, return the charge's default bucket
			return filter.ToDefaultFilter()
		}
	}
}
