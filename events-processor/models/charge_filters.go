package models

import (
	"github.com/getlago/lago/events-processor/utils"
	"gorm.io/gorm"
)

type ChargeFilter struct {
	ID               string            `gorm:"primaryKey;->" json:"id"`
	OrganizationID   string            `gorm:"->" json:"organization_id"`
	ChargeID         string            `gorm:"->" json:"charge_id"`
	PricingGroupKeys utils.StringArray `gorm:"->" json:"properties.pricing_group_keys"`
	CreatedAt        utils.NullTime    `gorm:"->" json:"created_at"`
	UpdatedAt        utils.NullTime    `gorm:"->" json:"updated_at"`
	DeletedAt        utils.NullTime    `gorm:"->" json:"deleted_at"`
}

func GetAllChargeFilters(db *gorm.DB) utils.Result[[]ChargeFilter] {
	config := StreamQueryConfig{
		TableName: "charge_filters",
		SelectFields: []string{
			"id",
			"organization_id",
			"charge_id",
			"properties->>'pricing_group_keys' as pricing_group_keys",
			"created_at",
			"updated_at",
			"deleted_at",
		},
		WhereCondition: "deleted_at IS NULL",
		WhereArgs:      []any{},
		LogInterval:    10000,
	}

	return GetAllWithStreaming[ChargeFilter](db, config)
}
