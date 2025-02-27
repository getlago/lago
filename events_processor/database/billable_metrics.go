package database

import (
	"time"

	"github.com/getlago/lago/events-processor/utils"
	"gorm.io/gorm"
)

type BillableMetric struct {
	ID             string         `gorm:"primaryKey;->"`
	OrganizationID string         `gorm:"->"`
	Code           string         `gorm:"->"`
	FieldName      string         `gorm:"->"`
	Expression     string         `gorm:"->"`
	CreatedAt      time.Time      `gorm:"->"`
	UpdatedAt      time.Time      `gorm:"->"`
	DeletedAt      gorm.DeletedAt `gorm:"index;->"`
}

func (db *DB) FetchBillableMetric(organizationID string, code string) utils.Result[*BillableMetric] {
	// TODO: take deleted records into account

	var bm *BillableMetric
	result := db.connection.First(bm, "organization_id = ? AND code = ?", organizationID, code)
	if result.Error != nil {
		return failedBillabmeMetricResult(result.Error)
	}

	return utils.SuccessResult(bm)
}

func failedBillabmeMetricResult(err error) utils.Result[*BillableMetric] {
	return utils.FailedResult[*BillableMetric](err)
}
