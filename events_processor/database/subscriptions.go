package database

import (
	"database/sql"
	"time"

	"github.com/getlago/lago/events-processor/utils"
)

type Subscription struct {
	ID                     string       `gorm:"primaryKey;->"`
	SubscriptionID         string       `gorm:"->"`
	ExternalSubscriptionID string       `gorm:"->"`
	PlanID                 string       `gorm:"->"`
	OrganizationID         string       `gorm:"->"`
	CreatedAt              time.Time    `gorm:"->"`
	UpdatedAt              time.Time    `gorm:"->"`
	StartedAt              sql.NullTime `gorm:"->"`
	TerminatedAt           sql.NullTime `gorm:"->"`
}

func (db *DB) FetchSubscription(organizationID string, externalID string, timestamp time.Time) utils.Result[*Subscription] {
	var sub *Subscription

	var conditions = `
		customers.organization_id = ?
		subscriptions.external_id = ?
		date_trunc('millisecond', subscriptions.started_at::timestamp) <= ?::timestamp
		AND (subscriptions.terminated_at IS NULL OR date_trunc('millisecond', subscriptions.terminated_at::timestamp) >= ?)
	`
	result := db.connection.
		Joins("INNER JOIN customers ON customers.id = subscriptions.customer_id").
		Order("terminated_at DESC NULLS FIRST, started_at DESC").
		First(sub, conditions, organizationID, externalID, timestamp, timestamp)

	if result.Error != nil {
		return failedSubscriptionResult(result.Error)
	}

	return utils.SuccessResult(sub)
}

func failedSubscriptionResult(err error) utils.Result[*Subscription] {
	return utils.FailedResult[*Subscription](err)
}
