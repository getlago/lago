package models

import "time"

type RefreshedSubscription struct {
	ID             string    `json:"subscription_id"`
	OrganizationID string    `json:"organization_id"`
	RefreshedAt    time.Time `json:"refreshed_at"`
}

type RefreshedSubscriptions struct {
	Values map[string]RefreshedSubscription
}

func (rss *RefreshedSubscriptions) GetValues() []RefreshedSubscription {
	values := make([]RefreshedSubscription, 0, len(rss.Values))

	for _, v := range rss.Values {
		values = append(values, v)
	}

	return values
}
