package models

import (
	"time"

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
