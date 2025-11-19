package models

import (
	"github.com/getlago/lago/events-processor/utils"
	"gorm.io/gorm"
)

type Charge struct {
	ID               string            `gorm:"primaryKey;->" json:"id"`
	OrganizationID   string            `gorm:"->" json:"organization_id"`
	PlanID           string            `gorm:"->" json:"plan_id"`
	BillableMetricID string            `gorm:"->" json:"billable_metric_id"`
	PayInAdvance     bool              `gorm:"->" json:"pay_in_advance"`
	PricingGroupKeys utils.StringArray `gorm:"->" json:"properties.pricing_group_keys"`
	CreatedAt        utils.NullTime    `gorm:"->" json:"created_at"`
	UpdatedAt        utils.NullTime    `gorm:"->" json:"updated_at"`
	DeletedAt        utils.NullTime    `gorm:"->" json:"deleted_at"`
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
			"properties->>'pricing_group_keys' as pricing_group_keys",
			"created_at",
			"updated_at",
			"deleted_at",
		},
		WhereCondition: "deleted_at IS NULL",
		WhereArgs:      []interface{}{},
		LogInterval:    50000,
	}

	return GetAllWithStreaming[Charge](db, config)
}
