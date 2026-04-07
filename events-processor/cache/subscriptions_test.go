package cache

import (
	"fmt"
	"testing"

	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/utils"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/twmb/franz-go/pkg/kgo"
)

func TestBuildSubscriptionKey(t *testing.T) {
	cache := setupTestCache(t)

	testModel := struct {
		externalID     string
		organizationID string
		id             string
	}{
		id:             "123",
		externalID:     "sub1",
		organizationID: "org-123",
	}

	expectedKey := "sub:org-123:sub1:123"
	key := cache.buildSubscriptionKey(testModel.organizationID, testModel.externalID, testModel.id)
	assert.Equal(t, expectedKey, key)
}

func TestSetSubscription_Success(t *testing.T) {
	cache := setupTestCache(t)

	orgID := "org-123"
	sub := &models.Subscription{
		ID:             "123",
		OrganizationID: &orgID,
		ExternalID:     "sub1",
		CreatedAt:      utils.NowNullTime(),
		UpdatedAt:      utils.NowNullTime(),
	}

	result := cache.SetSubscription(sub)

	assert.True(t, result.Success())
	assert.True(t, result.Value())
}

func TestGetSubscription_Success(t *testing.T) {
	cache := setupTestCache(t)

	orgID := "org-123"
	sub := &models.Subscription{
		ID:             "123",
		OrganizationID: &orgID,
		ExternalID:     "sub1",
		CreatedAt:      utils.NowNullTime(),
		UpdatedAt:      utils.NowNullTime(),
	}

	cache.SetSubscription(sub)

	result := cache.GetSubscription("org-123", "sub1", "123")

	require.True(t, result.Success())
	retrieved := result.Value()
	assert.Equal(t, sub.ID, retrieved.ID)
	assert.Equal(t, sub.ExternalID, retrieved.ExternalID)
	assert.Equal(t, sub.OrganizationID, retrieved.OrganizationID)
}

func TestSetSubscription_NilOrganizationID(t *testing.T) {
	cache := setupTestCache(t)

	sub := &models.Subscription{
		ID:             "123",
		OrganizationID: nil,
		ExternalID:     "sub1",
	}

	result := cache.SetSubscription(sub)

	assert.True(t, result.Failure())
	assert.Contains(t, result.Error().Error(), "nil OrganizationID")
}

func TestDeleteSubscription_NilOrganizationID(t *testing.T) {
	cache := setupTestCache(t)

	sub := &models.Subscription{
		ID:             "123",
		OrganizationID: nil,
		ExternalID:     "sub1",
	}

	result := cache.DeleteSubscription(sub)

	assert.True(t, result.Failure())
	assert.Contains(t, result.Error().Error(), "nil OrganizationID")
}

func TestProcessRecord_Subscription_NilOrganizationID(t *testing.T) {
	cache := setupTestCache(t)

	config := ConsumerConfig[models.Subscription]{
		ModelName: "subscription",
		IsDeleted: func(sub *models.Subscription) bool {
			return sub.TerminatedAt.Valid
		},
		GetKey: func(sub *models.Subscription) string {
			key, _ := cache.subscriptionKey(sub)
			return key
		},
		GetID: func(sub *models.Subscription) string {
			return sub.ID
		},
		GetUpdatedAt: func(sub *models.Subscription) int64 {
			return sub.UpdatedAt.Time.UnixMilli()
		},
		GetCached: func(sub *models.Subscription) utils.Result[*models.Subscription] {
			if sub.OrganizationID == nil {
				return utils.FailedResult[*models.Subscription](fmt.Errorf("nil OrganizationID"))
			}
			return cache.GetSubscription(*sub.OrganizationID, sub.ExternalID, sub.ID)
		},
		SetCache: func(sub *models.Subscription) utils.Result[bool] {
			return cache.SetSubscription(sub)
		},
		Delete: func(sub *models.Subscription) utils.Result[bool] {
			return cache.DeleteSubscription(sub)
		},
	}

	// Debezium payload with null organization_id — should not panic
	record := &kgo.Record{
		Value: []byte(`{"id":"sub-1","organization_id":null,"external_id":"ext-1","updated_at":1700000000}`),
		Topic: "test_topic",
	}

	assert.NotPanics(t, func() {
		processRecord(cache, record, config)
	})

	// SetCache is called but fails gracefully inside SetSubscription
	// The key point: no panic on nil OrganizationID
	result := cache.GetSubscription("", "ext-1", "sub-1")
	assert.True(t, result.Failure(), "Subscription should not be cached with nil OrganizationID")
}

func TestGetSubscription_NotFound(t *testing.T) {
	cache := setupTestCache(t)

	result := cache.GetSubscription("notorg", "sub1", "123")

	assert.True(t, result.Failure())
}
