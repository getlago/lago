package models

import (
	"database/sql"
	"time"

	"gorm.io/gorm"

	"github.com/getlago/lago/events-processor/utils"
)

type Subscription struct {
	ID           string       `gorm:"primaryKey;->"`
	OrganizationID *string `gorm:"->"`
	ExternalID   string       `gorm:"->"`
	PlanID       string       `gorm:"->"`
	CreatedAt    time.Time    `gorm:"->"`
	UpdatedAt    time.Time    `gorm:"->"`
	StartedAt    sql.NullTime `gorm:"->"`
	TerminatedAt sql.NullTime `gorm:"->"`
}

func (store *ApiStore) FetchSubscription(organizationID string, externalID string, timestamp time.Time) utils.Result[*Subscription] {
	var sub Subscription

	var conditions = `
		subscriptions.organization_id = ?
		AND subscriptions.external_id = ?
		AND date_trunc('millisecond', subscriptions.started_at::timestamp) <= ?::timestamp
		AND (subscriptions.terminated_at IS NULL OR date_trunc('millisecond', subscriptions.terminated_at::timestamp) >= ?)
	`
	result := store.db.Connection.
		Table("subscriptions").
		Unscoped().
		Where(conditions, organizationID, externalID, timestamp, timestamp).
		Order("terminated_at DESC NULLS FIRST, started_at DESC").
		Limit(1).
		Find(&sub)

	if result.Error != nil {
		return failedSubscriptionResult(result.Error)
	}
	if sub.ID == "" {
		return failedSubscriptionResult(gorm.ErrRecordNotFound)
	}

	return utils.SuccessResult(&sub)
}

func GetAllSubscriptions(db *gorm.DB) utils.Result[[]Subscription] {
	var subscriptions []Subscription
	result := db.Find(&subscriptions, "terminated_at IS NOT NULL")
	if result.Error != nil {
		return utils.FailedResult[[]Subscription](result.Error)
	}

	return utils.SuccessResult(subscriptions)
}

func failedSubscriptionResult(err error) utils.Result[*Subscription] {
	result := utils.FailedResult[*Subscription](err)

	if err.Error() == gorm.ErrRecordNotFound.Error() {
		result = result.NonCapturable().NonRetryable()
	}

	return result
}
