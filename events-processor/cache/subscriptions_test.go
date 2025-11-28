package cache

import (
	"testing"

	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/utils"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
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

func TestGetSubscription_NotFound(t *testing.T) {
	cache := setupTestCache(t)

	result := cache.GetSubscription("notorg", "sub1", "123")

	assert.True(t, result.Failure())
}
