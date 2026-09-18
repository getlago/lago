package models

import (
	"github.com/getlago/lago/events-processor/utils"
	"gorm.io/gorm"
)

type Charge struct {
	ID                  string            `gorm:"primaryKey;->" json:"id"`
	OrganizationID      string            `gorm:"->" json:"organization_id"`
	PlanID              string            `gorm:"->" json:"plan_id"`
	BillableMetricID    string            `gorm:"->" json:"billable_metric_id"`
	PayInAdvance        bool              `gorm:"->" json:"pay_in_advance"`
	AcceptsTargetWallet bool              `gorm:"->" json:"accepts_target_wallet"`
	PricingGroupKeys    utils.StringArray `gorm:"type:jsonb;->" json:"properties.pricing_group_keys"`
	CreatedAt           utils.NullTime    `gorm:"->" json:"created_at"`
	UpdatedAt           utils.NullTime    `gorm:"->" json:"updated_at"`
	DeletedAt           utils.NullTime    `gorm:"->" json:"deleted_at"`
}

func GetAllCharges(db *gorm.DB) utils.Result[[]Charge] {
	config := StreamQueryConfig{
		TableName: "charges",
		SelectFields: []string{
			"id",
			"organization_id",
			"plan_id",
			"billable_metric_id",
			"pay_in_advance",
			"accepts_target_wallet",
			"properties->'pricing_group_keys' as pricing_group_keys",
			"created_at",
			"updated_at",
			"deleted_at",
		},
		WhereCondition: "deleted_at IS NULL",
		WhereArgs:      []any{},
		LogInterval:    50000,
	}

	return GetAllWithStreaming[Charge](db, config)
}

// HasPayInAdvanceCharge reports whether the plan has at least one pay in advance charge for the
// billable metric. It replaces the lookup that used to go through the flat_filters view, and only
// needs the charges table.
func (store *ApiStore) HasPayInAdvanceCharge(organizationID string, planID string, billableMetricID string) utils.Result[bool] {
	var ids []string

	result := store.db.Connection.
		Table("charges").
		Select("id").
		Where(
			"organization_id = ? AND plan_id = ? AND billable_metric_id = ? AND pay_in_advance IS TRUE AND deleted_at IS NULL",
			organizationID,
			planID,
			billableMetricID,
		).
		Limit(1).
		Find(&ids)
	if result.Error != nil {
		return utils.FailedBoolResult(result.Error)
	}

	return utils.SuccessResult(len(ids) > 0)
}
