package models

import (
	"time"

	"gorm.io/gorm"

	"github.com/getlago/lago/events-processors/utils"
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

func (store *ApiStore) AnyInAdvanceCharge(planID string, billableMetricID string) utils.Result[bool] {
	var count int64

	result := store.db.Connection.Model(&Charge{}).
		Where("plan_id = ? AND billable_metric_id = ?", planID, billableMetricID).
		Where("pay_in_advance = true").
		Count(&count)
	if result.Error != nil {
		return utils.FailedBoolResult(result.Error)
	}

	return utils.SuccessResult(count > 0)
}
