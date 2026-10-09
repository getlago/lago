package cache

import (
	"sort"
	"testing"

	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/utils"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestBuildUsageAttributionTypeKey(t *testing.T) {
	cache := setupTestCache(t)

	key := cache.buildUsageAttributionTypeKey("org-123", "uat-123")
	assert.Equal(t, "uat:org-123:uat-123", key)
}

func TestUnmarshalUsageAttributionTypeChange(t *testing.T) {
	t.Run("parses a change captured by Debezium", func(t *testing.T) {
		data := []byte(`{
			"id": "uat-2",
			"organization_id": "org-123",
			"code": "user",
			"attribution_keys": ["user_id", "userId"],
			"parent_id": "uat-1",
			"created_at": 1791370000000000,
			"updated_at": 1791370000000000,
			"deleted_at": null
		}`)

		var uat models.UsageAttributionType
		require.NoError(t, utils.UnmarshalNestedJSON(data, &uat))

		assert.Equal(t, "uat-2", uat.ID)
		assert.Equal(t, "org-123", uat.OrganizationID)
		assert.Equal(t, "user", uat.Code)
		assert.Equal(t, utils.StringArray{"user_id", "userId"}, uat.AttributionKeys)
		assert.Equal(t, "uat-1", *uat.ParentID)
		assert.True(t, uat.UpdatedAt.Valid)
		assert.False(t, uat.DeletedAt.Valid)
	})

	t.Run("parses a root type that was deleted", func(t *testing.T) {
		data := []byte(`{
			"id": "uat-1",
			"organization_id": "org-123",
			"code": "department",
			"attribution_keys": ["department_id"],
			"parent_id": null,
			"updated_at": 1791370000000000,
			"deleted_at": 1791370000000000
		}`)

		var uat models.UsageAttributionType
		require.NoError(t, utils.UnmarshalNestedJSON(data, &uat))

		assert.Nil(t, uat.ParentID)
		assert.True(t, uat.DeletedAt.Valid)
	})
}

func TestSearchUsageAttributionTypes(t *testing.T) {
	cache := setupTestCache(t)

	types := []*models.UsageAttributionType{
		{ID: "uat-1", OrganizationID: "org-123", Code: "department", AttributionKeys: utils.StringArray{"department_id"}, UpdatedAt: utils.NowNullTime()},
		{ID: "uat-2", OrganizationID: "org-123", Code: "user", AttributionKeys: utils.StringArray{"user_id", "userId"}, ParentID: utils.StringPtr("uat-1"), UpdatedAt: utils.NowNullTime()},
		{ID: "uat-3", OrganizationID: "org-456", Code: "team", AttributionKeys: utils.StringArray{"team_id"}, UpdatedAt: utils.NowNullTime()},
	}
	for _, uat := range types {
		require.True(t, cache.SetUsageAttributionType(uat).Success())
	}

	t.Run("returns the organization usage attribution types only", func(t *testing.T) {
		result := cache.SearchUsageAttributionTypes("org-123")

		require.True(t, result.Success())
		found := result.Value()
		sort.Slice(found, func(i, j int) bool { return found[i].ID < found[j].ID })

		require.Len(t, found, 2)
		assert.Equal(t, "department", found[0].Code)
		assert.Equal(t, "user", found[1].Code)
		assert.Equal(t, utils.StringArray{"user_id", "userId"}, found[1].AttributionKeys)
		assert.Equal(t, "uat-1", *found[1].ParentID)
	})

	t.Run("returns nothing for an organization without usage attribution types", func(t *testing.T) {
		result := cache.SearchUsageAttributionTypes("org-789")

		assert.True(t, result.Success())
		assert.Empty(t, result.Value())
	})

	t.Run("no longer returns a deleted usage attribution type", func(t *testing.T) {
		require.True(t, cache.DeleteUsageAttributionType(types[0]).Success())

		result := cache.SearchUsageAttributionTypes("org-123")

		require.True(t, result.Success())
		require.Len(t, result.Value(), 1)
		assert.Equal(t, "user", result.Value()[0].Code)
	})
}
