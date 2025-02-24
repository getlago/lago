package models

import (
	"time"

	"gorm.io/gorm"
)

type Charge struct {
	ID               string         `gorm:"primaryKey;->"`
	BillableMetricID string         `gorm:"->"`
	PlanID           string         `gorm:"->"`
	PayInAdvance     bool           `gorm:"->"`
	CreatedAt        time.Time      `gorm:"->"`
	UpdatedAt        time.Time      `gorm:"->"`
	DeletedAt        gorm.DeletedAt `gorm:"index;->"`
}
