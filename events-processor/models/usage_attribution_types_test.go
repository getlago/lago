package models

import (
	"errors"
	"regexp"
	"strings"
	"testing"
	"time"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/getlago/lago/events-processor/utils"
)

var fetchUsageAttributionTypesQuery = regexp.QuoteMeta(
	`SELECT * FROM "usage_attribution_types" WHERE organization_id = $1 AND deleted_at IS NULL`,
)

func TestFetchUsageAttributionTypes(t *testing.T) {
	orgID := "1a901a90-1a90-1a90-1a90-1a901a901a90"

	t.Run("should return the organization usage attribution types", func(t *testing.T) {
		store, mock, cleanup := setupApiStore(t)
		defer cleanup()

		now := time.Now()
		columns := []string{"id", "organization_id", "code", "attribution_keys", "parent_id", "created_at", "updated_at", "deleted_at"}
		rows := sqlmock.NewRows(columns).
			AddRow("uat-department", orgID, "department", "{department_id}", nil, now, now, nil).
			AddRow("uat-user", orgID, "user", "{user_id,userId}", "uat-department", now, now, nil)

		mock.ExpectQuery(fetchUsageAttributionTypesQuery).
			WithArgs(orgID).
			WillReturnRows(rows)

		result := store.FetchUsageAttributionTypes(orgID)

		require.True(t, result.Success())
		types := result.Value()
		require.Len(t, types, 2)

		assert.Equal(t, "department", types[0].Code)
		assert.Equal(t, utils.StringArray{"department_id"}, types[0].AttributionKeys)
		assert.Nil(t, types[0].ParentID)

		assert.Equal(t, "user", types[1].Code)
		assert.Equal(t, utils.StringArray{"user_id", "userId"}, types[1].AttributionKeys)
		assert.Equal(t, "uat-department", *types[1].ParentID)
	})

	t.Run("should return an empty list when the organization has no usage attribution types", func(t *testing.T) {
		store, mock, cleanup := setupApiStore(t)
		defer cleanup()

		mock.ExpectQuery(fetchUsageAttributionTypesQuery).
			WithArgs(orgID).
			WillReturnRows(sqlmock.NewRows([]string{"id"}))

		result := store.FetchUsageAttributionTypes(orgID)

		assert.True(t, result.Success())
		assert.Empty(t, result.Value())
	})

	t.Run("should return a retryable error when the query fails", func(t *testing.T) {
		store, mock, cleanup := setupApiStore(t)
		defer cleanup()

		dbError := errors.New("database connection failed")
		mock.ExpectQuery(fetchUsageAttributionTypesQuery).
			WithArgs(orgID).
			WillReturnError(dbError)

		result := store.FetchUsageAttributionTypes(orgID)

		assert.False(t, result.Success())
		assert.Equal(t, dbError, result.Error())
		assert.True(t, result.IsRetryable())
		assert.True(t, result.IsCapturable())
	})
}

func TestBuildAttributionLabels(t *testing.T) {
	department := &UsageAttributionType{Code: "department", AttributionKeys: utils.StringArray{"department_id"}}
	user := &UsageAttributionType{Code: "user", AttributionKeys: utils.StringArray{"user_id", "userId"}}
	model := &UsageAttributionType{Code: "model", AttributionKeys: utils.StringArray{"model"}}
	types := []*UsageAttributionType{department, user, model}

	tests := []struct {
		name       string
		types      []*UsageAttributionType
		properties map[string]any
		expected   map[string]string
	}{
		{
			name:       "stamps the full chain and the flat keys",
			types:      types,
			properties: map[string]any{"department_id": "rnd", "user_id": "alice", "model": "opus", "tokens": 1000},
			expected:   map[string]string{"department": "rnd", "user": "alice", "model": "opus"},
		},
		{
			name:       "only stamps the types found in the properties",
			types:      types,
			properties: map[string]any{"user_id": "alice"},
			expected:   map[string]string{"user": "alice"},
		},
		{
			name:       "falls back on the next attribution key",
			types:      types,
			properties: map[string]any{"userId": "bob"},
			expected:   map[string]string{"user": "bob"},
		},
		{
			name:       "uses the first attribution key when several are present",
			types:      types,
			properties: map[string]any{"user_id": "alice", "userId": "bob"},
			expected:   map[string]string{"user": "alice"},
		},
		{
			name:       "falls back on the next attribution key when the first one is empty",
			types:      types,
			properties: map[string]any{"user_id": "", "userId": "bob"},
			expected:   map[string]string{"user": "bob"},
		},
		{
			name:       "formats numeric and boolean values",
			types:      types,
			properties: map[string]any{"user_id": float64(42), "model": true},
			expected:   map[string]string{"user": "42", "model": "true"},
		},
		{
			name:       "skips null, nested and too long values",
			types:      types,
			properties: map[string]any{"department_id": nil, "user_id": map[string]any{"id": "alice"}, "model": strings.Repeat("a", 256)},
			expected:   nil,
		},
		{
			name:       "keeps values at the maximum length counted in characters",
			types:      types,
			properties: map[string]any{"model": strings.Repeat("é", 255)},
			expected:   map[string]string{"model": strings.Repeat("é", 255)},
		},
		{
			name:       "returns no labels when no attribution key is present",
			types:      types,
			properties: map[string]any{"tokens": 1000},
			expected:   nil,
		},
		{
			name:       "returns no labels without usage attribution types",
			types:      nil,
			properties: map[string]any{"user_id": "alice"},
			expected:   nil,
		},
		{
			name:       "returns no labels without properties",
			types:      types,
			properties: nil,
			expected:   nil,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			assert.Equal(t, tt.expected, BuildAttributionLabels(tt.types, tt.properties))
		})
	}
}
