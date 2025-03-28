package models

import (
	"time"

	"gorm.io/gorm"

	"github.com/getlago/lago/events-processor/utils"
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

func (store *ApiStore) FetchBillableMetric(organizationID string, code string) utils.Result[*BillableMetric] {
	var bm BillableMetric
	result := store.db.Connection.First(&bm, "organization_id = ? AND code = ?", organizationID, code)
	if result.Error != nil {
		return failedBillabmeMetricResult(result.Error)
	}

	return utils.SuccessResult(&bm)
}

func failedBillabmeMetricResult(err error) utils.Result[*BillableMetric] {
	result := utils.FailedResult[*BillableMetric](err)

	if err.Error() == gorm.ErrRecordNotFound.Error() {
		result = result.NonCapturable().NonRetryable()
	}

	return result
}
