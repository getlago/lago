package models

import (
	"fmt"
	"strconv"
	"unicode/utf8"

	"gorm.io/gorm"

	"github.com/getlago/lago/events-processor/utils"
)

// MaxAttributionValueLength mirrors the validation of usage_attribution_values.value in the API,
// so that every stamped label can also be stored as an attribution value.
const MaxAttributionValueLength = 255

// UsageAttributionType is an account tree level declared by the organization (user, team, model...).
// An event is attributed to it through the first of its attribution keys found in the event properties.
type UsageAttributionType struct {
	ID              string            `gorm:"primaryKey;->" json:"id"`
	OrganizationID  string            `gorm:"->" json:"organization_id"`
	Code            string            `gorm:"->" json:"code"`
	AttributionKeys utils.StringArray `gorm:"type:varchar[];->" json:"attribution_keys"`
	ParentID        *string           `gorm:"->" json:"parent_id"`
	CreatedAt       utils.NullTime    `gorm:"->" json:"created_at"`
	UpdatedAt       utils.NullTime    `gorm:"->" json:"updated_at"`
	DeletedAt       utils.NullTime    `gorm:"->" json:"deleted_at"`
}

func (store *ApiStore) FetchUsageAttributionTypes(organizationID string) utils.Result[[]*UsageAttributionType] {
	var types []*UsageAttributionType

	result := store.db.Connection.
		Table("usage_attribution_types").
		Where("organization_id = ? AND deleted_at IS NULL", organizationID).
		Find(&types)
	if result.Error != nil {
		return utils.FailedResult[[]*UsageAttributionType](result.Error)
	}

	return utils.SuccessResult(types)
}

func GetAllUsageAttributionTypes(db *gorm.DB) utils.Result[[]UsageAttributionType] {
	config := StreamQueryConfig{
		TableName: "usage_attribution_types",
		SelectFields: []string{
			"id",
			"organization_id",
			"code",
			"attribution_keys",
			"parent_id",
			"created_at",
			"updated_at",
			"deleted_at",
		},
		WhereCondition: "deleted_at IS NULL",
		WhereArgs:      []any{},
		LogInterval:    10000,
	}

	return GetAllWithStreaming[UsageAttributionType](db, config)
}

// BuildAttributionLabels resolves the account tree labels of an event: for each attribution type,
// the value of the first of its attribution keys present in the properties, keyed by the type code.
// Events are expected to carry the full ancestor chain, so no placement is looked up.
func BuildAttributionLabels(types []*UsageAttributionType, properties map[string]any) map[string]string {
	if len(types) == 0 || len(properties) == 0 {
		return nil
	}

	labels := make(map[string]string)

	for _, attributionType := range types {
		for _, key := range attributionType.AttributionKeys {
			value, ok := attributionValue(properties[key])
			if !ok {
				continue
			}

			labels[attributionType.Code] = value
			break
		}
	}

	if len(labels) == 0 {
		return nil
	}

	return labels
}

// attributionValue formats a property as a label value. Missing, empty, nested (objects, arrays)
// and too long values cannot identify an attribution value.
func attributionValue(property any) (string, bool) {
	var value string

	switch v := property.(type) {
	case nil, map[string]any, []any:
		return "", false
	case float64:
		value = strconv.FormatFloat(v, 'f', -1, 64)
	default:
		value = fmt.Sprintf("%v", v)
	}

	if value == "" || utf8.RuneCountInString(value) > MaxAttributionValueLength {
		return "", false
	}

	return value, true
}
