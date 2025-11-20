package models

import (
	"github.com/getlago/lago/events-processor/utils"
	"gorm.io/gorm"
)

type BillableMetricFilter struct {
	ID               string            `gorm:"primaryKey;->" json:"id"`
	OrganizationID   string            `gorm:"->" json:"organization_id"`
	BillableMetricID string            `gorm:"->" json:"billable_metric_id"`
	Key              string            `gorm:"->" json:"key"`
	Values           utils.StringArray `gorm:"type:jsonb;->" json:"values"`
	CreatedAt        utils.NullTime    `gorm:"->" json:"created_at"`
	UpdatedAt        utils.NullTime    `gorm:"->" json:"updated_at"`
	DeletedAt        utils.NullTime    `gorm:"->" json:"deleted_at"`
}

func GetAllBillableMetricFilters(db *gorm.DB) utils.Result[[]BillableMetricFilter] {
	config := StreamQueryConfig{
		TableName: "billable_metric_filters",
		SelectFields: []string{
			"id",
			"organization_id",
			"billable_metric_id",
			"key",
			"values",
			"created_at",
			"updated_at",
			"deleted_at",
		},
		WhereCondition: "deleted_at IS NULL",
		WhereArgs:      []any{},
		LogInterval:    10000,
	}

	return GetAllWithStreaming[BillableMetricFilter](db, config)
}
