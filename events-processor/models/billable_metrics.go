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
	ID              string          `gorm:"primaryKey;->" json:"id"`
	OrganizationID  string          `gorm:"->" json:"organization_id"`
	Code            string          `gorm:"->" json:"code"`
	AggregationType AggregationType `gorm:"->" json:"aggregation_type"`
	FieldName       string          `gorm:"->" json:"field_name"`
	Expression      string          `gorm:"->" json:"expression"`
	CreatedAt       time.Time       `gorm:"->" json:"created_at"`
	UpdatedAt       time.Time       `gorm:"->" json:"updated_at"`
	DeletedAt       gorm.DeletedAt  `gorm:"index;->" json:"deleted_at"`
}

func (store *ApiStore) FetchBillableMetric(organizationID string, code string) utils.Result[*BillableMetric] {
	var bm BillableMetric
	result := store.db.Connection.First(&bm, "organization_id = ? AND code = ?", organizationID, code)
	if result.Error != nil {
		return failedBillableMetricResult(result.Error)
	}

	return utils.SuccessResult(&bm)
}

func GetAllBillableMetrics(db *gorm.DB) utils.Result[[]BillableMetric] {
	var billableMetrics []BillableMetric
	result := db.Find(&billableMetrics, "deleted_at IS NULL")
	if result.Error != nil {
		return utils.FailedResult[[]BillableMetric](result.Error)
	}

	return utils.SuccessResult(billableMetrics)
}

func failedBillableMetricResult(err error) utils.Result[*BillableMetric] {
	result := utils.FailedResult[*BillableMetric](err)

	if err.Error() == gorm.ErrRecordNotFound.Error() {
		result = result.NonCapturable().NonRetryable()
	}

	return result
}
