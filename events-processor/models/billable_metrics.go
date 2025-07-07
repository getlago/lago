package models

import (
	"time"

	"gorm.io/gorm"

	"github.com/getlago/lago/events-processor/utils"
)

type AggregationType int

const (
	AggregationTypeCount = iota
	AggregationTypeSum
	AggregationTypeMax
	AggregationTypeUniqueCount
	_
	AggregationTypeWeightedSum
	AggregationTypeLatest
	AggregationTypeCustom
)

func (t AggregationType) String() string {
	aggType := ""

	switch t {
	case AggregationTypeCount:
		aggType = "count"
	case AggregationTypeSum:
		aggType = "sum"
	case AggregationTypeMax:
		aggType = "max"
	case AggregationTypeUniqueCount:
		aggType = "unique_count"
	case AggregationTypeWeightedSum:
		aggType = "weighted_sum"
	case AggregationTypeLatest:
		aggType = "latest"
	case AggregationTypeCustom:
		aggType = "custom"
	}

	return aggType

}

type BillableMetric struct {
	ID              string          `gorm:"primaryKey;->"`
	OrganizationID  string          `gorm:"->"`
	Code            string          `gorm:"->"`
	AggregationType AggregationType `gorm:"->"`
	FieldName       string          `gorm:"->"`
	Expression      string          `gorm:"->"`
	CreatedAt       time.Time       `gorm:"->"`
	UpdatedAt       time.Time       `gorm:"->"`
	DeletedAt       gorm.DeletedAt  `gorm:"index;->"`
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
