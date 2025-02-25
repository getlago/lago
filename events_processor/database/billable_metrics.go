package database

import (
	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/utils"
)

func (db *DB) FetchBillableMetric(organizationID string, code string) utils.Result[*models.BillableMetric] {
	// TODO: take deleted records into account

	var bm *models.BillableMetric
	result := db.connection.First(bm, "organization_id = ? AND code = ?", organizationID, code)
	if result.Error != nil {
		return failedBillabmeMetricResult(result.Error)
	}

	return utils.SuccessResult(bm)
}

func failedBillabmeMetricResult(err error) utils.Result[*models.BillableMetric] {
	return utils.FailedResult[*models.BillableMetric](err)
}
