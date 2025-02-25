package database

import (
	"time"

	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/utils"
)

func (db *DB) FetchSubscription(organizationID string, externalID string, timestamp time.Time) utils.Result[*models.Subscription] {
	var sub *models.Subscription

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

func failedSubscriptionResult(err error) utils.Result[*models.Subscription] {
	return utils.FailedResult[*models.Subscription](err)
}
