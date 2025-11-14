package models

import (
	"github.com/getlago/lago/events-processor/utils"
	"gorm.io/gorm"
)

type Charge struct {
	ID               string         `gorm:"primaryKey;->" json:"id"`
	OrganizationID   string         `gorm:"->" json:"organization_id"`
	PlanID           string         `gorm:"->" json:"plan_id"`
	BillableMetricID string         `gorm:"->" json:"billable_metric_id"`
	PayInAdvance     bool           `gorm:"->" json:"pay_in_advance"`
	CreatedAt        utils.NullTime `gorm:"->" json:"created_at"`
	UpdatedAt        utils.NullTime `gorm:"->" json:"updated_at"`
	DeletedAt        utils.NullTime `gorm:"->" json:"deleted_at"`
}

func GetAllCharges(db *gorm.DB) utils.Result[[]Charge] {
	var charges []Charge
	result := db.Select(
		"id",
		"organization_id",
		"plan_id",
		"billable_metric_id",
		"pay_in_advance",
		"created_at",
		"updated_at",
		"deleted_at",
	).Find(&charges, "deleted_at IS NULL")
	if result.Error != nil {
		return utils.FailedResult[[]Charge](result.Error)
	}

	return utils.SuccessResult(charges)
}
