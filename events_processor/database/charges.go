package database

import (
	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/utils"
)

func (db *DB) AnyInAdvanceCharge(planID string, billableMetricID string) utils.Result[bool] {
	// TODO: take deleted records into account
	var count int64

	result := db.connection.Model(&models.Charge{}).
		Where("plan_id = ? AND billable_metric_id = ?", planID, billableMetricID).
		Count(&count)
	if result.Error != nil {
		return utils.FailedBoolResult(result.Error)
	}

	return utils.SuccessResult(count > 0)
}
