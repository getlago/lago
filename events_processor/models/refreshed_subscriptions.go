package models

import "slices"

type RefreshedSubscriptions struct {
	IDs []string `json:"subscription_ids"`
}

func (rss *RefreshedSubscriptions) PushUnique(id string) string {
	if !slices.Contains(rss.IDs, id) {
		rss.IDs = append(rss.IDs, id)
	}

	return id
}
