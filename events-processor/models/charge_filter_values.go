package models

import (
	"github.com/getlago/lago/events-processor/utils"
	"gorm.io/gorm"
)

type ChargeFilterValue struct {
	ID                     string            `gorm:"primaryKey;->" json:"id"`
	OrganizationID         string            `gorm:"->" json:"organization_id"`
	ChargeFilterID         string            `gorm:"->" json:"charge_filter_id"`
	BillableMetricFilterID string            `gorm:"->" json:"billable_metric_filter_id"`
	Values                 utils.StringArray `gorm:"->" json:"values"`
	CreatedAt              utils.NullTime    `gorm:"->" json:"created_at"`
	UpdatedAt              utils.NullTime    `gorm:"->" json:"updated_at"`
	DeletedAt              utils.NullTime    `gorm:"->" json:"deleted_at"`
}

func GetAllChargeFilterValues(db *gorm.DB) utils.Result[[]ChargeFilterValue] {
	config := StreamQueryConfig{
		TableName: "charge_filter_values",
		SelectFields: []string{
			"id",
			"organization_id",
			"charge_filter_id",
			"billable_metric_filter_id",
			"values",
			"created_at",
			"updated_at",
			"deleted_at",
		},
		WhereCondition: "deleted_at IS NULL",
		WhereArgs:      []any{},
		LogInterval:    10000,
	}

	return GetAllWithStreaming[ChargeFilterValue](db, config)
}
