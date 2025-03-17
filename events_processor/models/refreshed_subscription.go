package models

import "time"

type RefreshedSubscription struct {
	ID             string    `json:"subscription_id"`
	OrganizationID string    `json:"organization_id"`
	RefreshedAt    time.Time `json:"refreshed_at"`
}
