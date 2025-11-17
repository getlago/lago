package models

import (
	"github.com/getlago/lago/events-processor/utils"
	"gorm.io/gorm"
)

type ChargeFilter struct {
	ID                     string            `gorm:"primaryKey;->" json:"id"`
	OrganizationID         string            `gorm:"->" json:"organization_id"`
	ChargeID               string            `gorm:"->" json:"charge_id"`
	BillableMetricFilterID string            `gorm:"->" json:"billable_metric_filter_id"`
	Values                 utils.StringArray `gorm:"type:jsonb;->" json:"values"`
	PricingGroupKeys       utils.StringArray `gorm:"->" json:"properties.pricing_group_keys"`
	CreatedAt              utils.NullTime    `gorm:"->" json:"created_at"`
	UpdatedAt              utils.NullTime    `gorm:"->" json:"updated_at"`
	DeletedAt              utils.NullTime    `gorm:"->" json:"deleted_at"`
}

func GetAllChargeFilters(db *gorm.DB) utils.Result[[]ChargeFilter] {
	var chargeFilters []ChargeFilter
	result := db.Select(
		"id",
		"organization_id",
		"charge_id",
		"billable_metric_filter_id",
		"values",
		"properties->>'pricing_group_keys' as pricing_group_keys",
		"created_at",
		"updated_at",
		"deleted_at",
	).Find(&chargeFilters, "deleted_at IS NULL")
	if result.Error != nil {
		return utils.FailedResult[[]ChargeFilter](result.Error)
	}

	return utils.SuccessResult(chargeFilters)
}
