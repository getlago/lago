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

type FlatFilter struct {
	OrganizationID        string            `gorm:"->"`
	BillableMetricCode    string            `gorm:"->"`
	PlanID                string            `gorm:"->"`
	ChargeID              string            `gorm:"->"`
	ChargeUpdatedAt       time.Time         `gorm:"->"`
	ChargeFilterID        *string           `gorm:"->"`
	ChargeFilterUpdatedAt *time.Time        `gorm:"->"`
	Filters               *FlatFilterValues `gorm:"type:jsonb"`
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

func (ff *FlatFilter) IsMatchingEvent(event EnrichedEvent) utils.Result[bool] {
	matching := true
	if ff.Filters == nil || len(*ff.Filters) == 0 {
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
