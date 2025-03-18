package models

import (
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestGetValues(t *testing.T) {
	values := make(map[string]RefreshedSubscription)
	refreshedValues := RefreshedSubscriptions{Values: values}

	sub1 := RefreshedSubscription{
		ID:             "sub_123",
		OrganizationID: "org_123",
		RefreshedAt:    time.Now(),
	}
	refreshedValues.Values[sub1.ID] = sub1

	sub2 := RefreshedSubscription{
		ID:             "sub_456",
		OrganizationID: "org_456",
		RefreshedAt:    time.Now(),
	}
	refreshedValues.Values[sub2.ID] = sub2

	result := refreshedValues.GetValues()
	assert.Equal(t, 2, len(result))
	assert.Contains(t, result, sub1)
	assert.Contains(t, result, sub2)
}
