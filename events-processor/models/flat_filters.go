package models

import (
	"database/sql/driver"
	"encoding/json"
	"fmt"
	"slices"
	"sync"
	"time"

	"gorm.io/gorm/schema"

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
	AcceptsTargetWallet   bool              `gorm:"type:boolean"`
}

var flatFilterSchema, _ = schema.Parse(&FlatFilter{}, &sync.Map{}, schema.NamingStrategy{})

func (store *ApiStore) FetchFlatFilters(organizationID string, planID string, billableMetricCode string) utils.Result[[]*FlatFilter] {
	var filters []*FlatFilter

	result := store.db.Connection.
		Table("flat_filters").
		Select(flatFilterSchema.DBNames).
		Where(
			"organization_id = ? AND plan_id = ? AND billable_metric_code = ?",
			organizationID,
			planID,
			billableMetricCode,
		).
		Find(&filters)
	if result.Error != nil {
		return utils.FailedResult[[]*FlatFilter](result.Error)
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
		OrganizationID:      ff.OrganizationID,
		BillableMetricCode:  ff.BillableMetricCode,
		PlanID:              ff.PlanID,
		ChargeID:            ff.ChargeID,
		ChargeUpdatedAt:     ff.ChargeUpdatedAt,
		PayInAdvance:        ff.PayInAdvance,
		AcceptsTargetWallet: ff.AcceptsTargetWallet,
		PricingGroupKeys:    ff.PricingGroupKeys,
	}

	return defaultFilter
}

// MatchingFilter returns the filter the event belongs to, the charge's default bucket when none
// matches.
//
// NOTE: This must return the same filter as the Ruby ChargeFilters::EventMatchingService, which
// does the same job for organizations on the Postgres events store. Both the usage cache key and
// the enriched event are built from it, so picking another one leaves the usage cache expiring a
// key the usage reader never wrote to.
func MatchingFilter(filters []FlatFilter, event *EnrichedEvent) *FlatFilter {
	var bestFilter *FlatFilter

	for i := range filters {
		filter := &filters[i]
		if !filter.HasFilters() || !filter.IsMatchingEvent(event).Value() {
			continue
		}

		if bestFilter == nil || filter.isBetterMatchThan(bestFilter) {
			bestFilter = filter
		}
	}

	// No filter matches the event, it falls into the charge's default bucket
	if bestFilter == nil {
		return filters[0].ToDefaultFilter()
	}

	return bestFilter
}

// isBetterMatchThan reports whether ff must be preferred over other: it matches more of the event
// properties, or as many but is older.
//
// NOTE: Ruby takes the first filter matching the most properties out of charge.filters, ordered by
// the ChargeFilter default scope (order(updated_at: :asc)), hence the tie-break on
// ChargeFilterUpdatedAt. The one on ChargeFilterID has no Ruby counterpart (Postgres resolves an
// ORDER BY tie arbitrarily), it only keeps us deterministic when two filters share a timestamp,
// rather than falling back to the order the filters were read in.
func (ff *FlatFilter) isBetterMatchThan(other *FlatFilter) bool {
	if keys, otherKeys := len(ff.Filters.Keys()), len(other.Filters.Keys()); keys != otherKeys {
		return keys > otherKeys
	}

	updatedAt, otherUpdatedAt := ff.chargeFilterUpdatedAt(), other.chargeFilterUpdatedAt()
	if !updatedAt.Equal(otherUpdatedAt) {
		return updatedAt.Before(otherUpdatedAt)
	}

	return ff.chargeFilterID() < other.chargeFilterID()
}

func (ff *FlatFilter) chargeFilterUpdatedAt() time.Time {
	if ff.ChargeFilterUpdatedAt == nil {
		return time.Time{}
	}

	return *ff.ChargeFilterUpdatedAt
}

func (ff *FlatFilter) chargeFilterID() string {
	if ff.ChargeFilterID == nil {
		return ""
	}

	return *ff.ChargeFilterID
}
