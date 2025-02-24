package models

import (
	"database/sql"
	"time"
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
