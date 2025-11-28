package cache

import (
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"testing"
	"time"

	"github.com/dgraph-io/badger/v4"
	"github.com/getlago/lago/events-processor/utils"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/twmb/franz-go/pkg/kgo"
)

type testModel struct {
	ID        string `json:"id"`
	Name      string `json:"name"`
	UpdatedAt int64  `json:"updated_at"`
	DeletedAt bool   `json:"deleted_at"`
}

func setupTestCache(t *testing.T) *Cache {
	cache, err := NewCache(CacheConfig{
		Context: context.Background(),
		Logger:  slog.Default(),
	})
	require.NoError(t, err)

	t.Cleanup(func() {
		cache.Close()
	})

	return cache
}

func createTestRecord(t *testing.T, model testModel) *kgo.Record {
	data, err := json.Marshal(model)
	require.NoError(t, err)

	return &kgo.Record{
		Value: data,
		Topic: "test_topic",
	}
}

func TestProcessRecord_CreateNew(t *testing.T) {
	cache := setupTestCache(t)

	var capturedModel testModel
	var capturedCalled bool
	config := ConsumerConfig[testModel]{
		ModelName:    "test_model",
		IsDeleted:    func(m *testModel) bool { return m.DeletedAt },
		GetKey:       func(m *testModel) string { return "test:" + m.ID },
		GetID:        func(m *testModel) string { return m.ID },
		GetUpdatedAt: func(m *testModel) int64 { return m.UpdatedAt },
		GetCached: func(m *testModel) utils.Result[*testModel] {
			return utils.FailedResult[*testModel](errors.New("not found")).NonRetryable()
		},
		SetCache: func(m *testModel) utils.Result[bool] {
			capturedModel = *m
			capturedCalled = true
			return utils.SuccessResult(true)
		},
	}

	model := testModel{
		ID:        "123",
		Name:      "Test",
		UpdatedAt: time.Now().UnixMilli(),
	}
	record := createTestRecord(t, model)

	processRecord(cache, record, config)

	require.True(t, capturedCalled, "SetCache should have been called")
	assert.Equal(t, model.ID, capturedModel.ID)
	assert.Equal(t, model.Name, capturedModel.Name)
}

func TestProcessRecord_UpdateExisting_NewerTimestamp(t *testing.T) {
	cache := setupTestCache(t)

	existingUpdatedAt := time.Now().UnixMilli()
	newUpdatedAt := existingUpdatedAt + 1000

	var setCalled bool
	config := ConsumerConfig[testModel]{
		ModelName:    "test_model",
		IsDeleted:    func(m *testModel) bool { return m.DeletedAt },
		GetKey:       func(m *testModel) string { return "test:" + m.ID },
		GetID:        func(m *testModel) string { return m.ID },
		GetUpdatedAt: func(m *testModel) int64 { return m.UpdatedAt },
		GetCached: func(m *testModel) utils.Result[*testModel] {
			return utils.SuccessResult(&testModel{
				ID:        "123",
				UpdatedAt: existingUpdatedAt,
			})
		},
		SetCache: func(m *testModel) utils.Result[bool] {
			setCalled = true
			return utils.SuccessResult(true)
		},
	}

	model := testModel{
		ID:        "123",
		Name:      "Updated",
		UpdatedAt: newUpdatedAt,
	}
	record := createTestRecord(t, model)

	processRecord(cache, record, config)

	assert.True(t, setCalled, "SetCache should be called for newer timestamp")
}

func TestProcessRecord_SkipUpdate_OlderTimestamp(t *testing.T) {
	cache := setupTestCache(t)

	existingUpdatedAt := time.Now().UnixMilli()
	oldUpdatedAt := existingUpdatedAt - 1000

	var setCalled bool
	config := ConsumerConfig[testModel]{
		ModelName:    "test_model",
		IsDeleted:    func(m *testModel) bool { return m.DeletedAt },
		GetKey:       func(m *testModel) string { return "test:" + m.ID },
		GetID:        func(m *testModel) string { return m.ID },
		GetUpdatedAt: func(m *testModel) int64 { return m.UpdatedAt },
		GetCached: func(m *testModel) utils.Result[*testModel] {
			return utils.SuccessResult(&testModel{
				ID:        "123",
				UpdatedAt: existingUpdatedAt,
			})
		},
		SetCache: func(m *testModel) utils.Result[bool] {
			setCalled = true
			return utils.SuccessResult(true)
		},
	}

	model := testModel{
		ID:        "123",
		UpdatedAt: oldUpdatedAt,
	}
	record := createTestRecord(t, model)

	processRecord(cache, record, config)

	assert.False(t, setCalled, "SetCache should not be called for older timestamp")
}

func TestProcessRecord_SkipUpdate_SameTimestamp(t *testing.T) {
	cache := setupTestCache(t)

	updatedAt := time.Now().UnixMilli()

	var setCalled bool
	config := ConsumerConfig[testModel]{
		ModelName:    "test_model",
		IsDeleted:    func(m *testModel) bool { return m.DeletedAt },
		GetKey:       func(m *testModel) string { return "test:" + m.ID },
		GetID:        func(m *testModel) string { return m.ID },
		GetUpdatedAt: func(m *testModel) int64 { return m.UpdatedAt },
		GetCached: func(m *testModel) utils.Result[*testModel] {
			return utils.SuccessResult(&testModel{
				ID:        "123",
				UpdatedAt: updatedAt,
			})
		},
		SetCache: func(m *testModel) utils.Result[bool] {
			setCalled = true
			return utils.SuccessResult(true)
		},
	}

	model := testModel{
		ID:        "123",
		UpdatedAt: updatedAt,
	}
	record := createTestRecord(t, model)

	processRecord(cache, record, config)

	assert.False(t, setCalled, "SetCache should not be called for same timestamp")
}

func TestProcessRecord_Delete_MatchingID(t *testing.T) {
	cache := setupTestCache(t)

	var deleteCalled bool
	config := ConsumerConfig[testModel]{
		ModelName:    "test_model",
		IsDeleted:    func(m *testModel) bool { return m.DeletedAt },
		GetKey:       func(m *testModel) string { return "test:" + m.ID },
		GetID:        func(m *testModel) string { return m.ID },
		GetUpdatedAt: func(m *testModel) int64 { return m.UpdatedAt },
		GetCached: func(m *testModel) utils.Result[*testModel] {
			return utils.SuccessResult(&testModel{ID: "123"})
		},
		SetCache: func(m *testModel) utils.Result[bool] {
			return utils.SuccessResult(true)
		},
		Delete: func(m *testModel) utils.Result[bool] {
			deleteCalled = true
			return utils.SuccessResult(true)
		},
	}

	model := testModel{ID: "123", Name: "Test"}
	key := config.GetKey(&model)
	data, _ := json.Marshal(model)
	cache.db.Update(func(txn *badger.Txn) error {
		return txn.Set([]byte(key), data)
	})

	deleteModel := testModel{ID: "123", DeletedAt: true}
	record := createTestRecord(t, deleteModel)

	processRecord(cache, record, config)

	assert.True(t, deleteCalled, "Delete should have been called")
}

func TestProcessRecord_Delete_NotInCache(t *testing.T) {
	cache := setupTestCache(t)

	config := ConsumerConfig[testModel]{
		ModelName:    "test_model",
		IsDeleted:    func(m *testModel) bool { return m.DeletedAt },
		GetKey:       func(m *testModel) string { return "test:" + m.ID },
		GetID:        func(m *testModel) string { return m.ID },
		GetUpdatedAt: func(m *testModel) int64 { return m.UpdatedAt },
		GetCached: func(m *testModel) utils.Result[*testModel] {
			return utils.FailedResult[*testModel](errors.New("not found")).NonRetryable()
		},
		SetCache: func(m *testModel) utils.Result[bool] {
			t.Fatal("SetCache should not be called for delete")
			return utils.SuccessResult(true)
		},
	}

	deleteModel := testModel{ID: "123", DeletedAt: true}
	record := createTestRecord(t, deleteModel)

	processRecord(cache, record, config)
}

func TestProcessRecord_InvalidJSON(t *testing.T) {
	cache := setupTestCache(t)

	var setCalled bool
	config := ConsumerConfig[testModel]{
		ModelName:    "test_model",
		IsDeleted:    func(m *testModel) bool { return m.DeletedAt },
		GetKey:       func(m *testModel) string { return "test:" + m.ID },
		GetID:        func(m *testModel) string { return m.ID },
		GetUpdatedAt: func(m *testModel) int64 { return m.UpdatedAt },
		GetCached: func(m *testModel) utils.Result[*testModel] {
			return utils.FailedResult[*testModel](errors.New("not found")).NonRetryable()
		},
		SetCache: func(m *testModel) utils.Result[bool] {
			setCalled = true
			return utils.SuccessResult(true)
		},
	}

	record := &kgo.Record{
		Value: []byte(`invalid json`),
		Topic: "test_topic",
	}

	processRecord(cache, record, config)

	assert.False(t, setCalled, "SetCache should not be called for invalid JSON")
}
