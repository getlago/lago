package database

import (
	"time"

	"github.com/getlago/lago/events-processor/utils"
	"gorm.io/gorm"
)

type Charge struct {
	ID               string         `gorm:"primaryKey;->"`
	BillableMetricID string         `gorm:"->"`
	PlanID           string         `gorm:"->"`
	PayInAdvance     bool           `gorm:"->"`
	CreatedAt        time.Time      `gorm:"->"`
	UpdatedAt        time.Time      `gorm:"->"`
	DeletedAt        gorm.DeletedAt `gorm:"index;->"`
}

func (db *DB) AnyInAdvanceCharge(planID string, billableMetricID string) utils.Result[bool] {
	var count int64

	result := db.connection.Model(&Charge{}).
		Where("plan_id = ? AND billable_metric_id = ?", planID, billableMetricID).
		Count(&count)
	if result.Error != nil {
		return utils.FailedBoolResult(result.Error)
	}

	return utils.SuccessResult(count > 0)
}
