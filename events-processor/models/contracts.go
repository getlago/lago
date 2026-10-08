package models

import (
	"sync"
	"time"

	"gorm.io/gorm"
	"gorm.io/gorm/schema"

	"github.com/getlago/lago/events-processor/utils"
)

const ContractStatusActive = "active"

// Contract is the product catalog counterpart of Subscription: catalog events
// carry its external id as external_contract_id.
type Contract struct {
	ID             string         `gorm:"primaryKey;->" json:"id"`
	OrganizationID *string        `gorm:"->" json:"organization_id"`
	ExternalID     string         `gorm:"->" json:"external_id"`
	Status         string         `gorm:"->" json:"status"`
	CreatedAt      utils.NullTime `gorm:"->" json:"created_at"`
	UpdatedAt      utils.NullTime `gorm:"->" json:"updated_at"`
	StartedAt      utils.NullTime `gorm:"->" json:"started_at"`
	TerminatedAt   utils.NullTime `gorm:"->" json:"terminated_at"`
	CanceledAt     utils.NullTime `gorm:"->" json:"canceled_at"`
}

var contractSchema, _ = schema.Parse(&Contract{}, &sync.Map{}, schema.NamingStrategy{})

// FetchContract returns the contract serving the event at timestamp. A canceled
// contract never started, so it never serves an event. A live contract wins over
// a terminated one, and an active contract over a pending one: a pending
// successor is not activated while its predecessor is active.
func (store *ApiStore) FetchContract(organizationID string, externalID string, timestamp time.Time) utils.Result[*Contract] {
	var contract Contract

	var conditions = `
		contracts.organization_id = ?
		AND contracts.external_id = ?
		AND contracts.canceled_at IS NULL
		AND date_trunc('millisecond', contracts.started_at::timestamp) <= ?::timestamp
		AND (contracts.terminated_at IS NULL OR date_trunc('millisecond', contracts.terminated_at::timestamp) >= ?)
	`
	result := store.db.Connection.
		Table("contracts").
		Select(contractSchema.DBNames).
		Where(conditions, organizationID, externalID, timestamp, timestamp).
		Order("terminated_at DESC NULLS FIRST, (status = 'active') DESC, started_at DESC").
		Limit(1).
		Find(&contract)

	if result.Error != nil {
		return failedContractResult(result.Error)
	}
	if contract.ID == "" {
		return failedContractResult(gorm.ErrRecordNotFound)
	}

	return utils.SuccessResult(&contract)
}

// GetAllContracts keeps contracts terminated less than a month ago, as for
// subscriptions, so late events of a terminated contract still resolve.
func GetAllContracts(db *gorm.DB) utils.Result[[]Contract] {
	oneMonthAgo := time.Now().AddDate(0, -1, 0)

	config := StreamQueryConfig{
		TableName: "contracts",
		SelectFields: []string{
			"id",
			"organization_id",
			"external_id",
			"status",
			"created_at",
			"updated_at",
			"started_at",
			"terminated_at",
			"canceled_at",
		},
		WhereCondition: "canceled_at IS NULL AND (terminated_at IS NULL OR terminated_at >= ?)",
		WhereArgs:      []any{oneMonthAgo},
		LogInterval:    50000,
	}

	return GetAllWithStreaming[Contract](db, config)
}

func failedContractResult(err error) utils.Result[*Contract] {
	result := utils.FailedResult[*Contract](err)

	if err.Error() == gorm.ErrRecordNotFound.Error() {
		result = result.NonCapturable().NonRetryable()
	}

	return result
}
