package cache

import (
	"context"
	"errors"
	"log/slog"
	"testing"
	"time"

	"github.com/dgraph-io/badger/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestNewCache(t *testing.T) {
	cache, err := NewCache(CacheConfig{
		Context: context.Background(),
		Logger:  slog.Default(),
	})

	require.NoError(t, err)
	require.NotNil(t, cache)
	require.NotNil(t, cache.db)
	require.NotNil(t, cache.logger)

	err = cache.Close()
	assert.NoError(t, err)
}

func TestSetJSON_Success(t *testing.T) {
	cache := setupTestCache(t)

	type testData struct {
		Name  string
		Value int
	}

	data := &testData{Name: "test", Value: 123}
	result := setJSON(cache, "test:key", data)

	assert.True(t, result.Success())
	assert.True(t, result.Value())
}

func TestGetJSON_Success(t *testing.T) {
	cache := setupTestCache(t)

	type testData struct {
		Name  string
		Value int
	}

	original := &testData{Name: "test", Value: 123}
	setJSON(cache, "test:key", original)

	result := getJSON[testData](cache, "test:key")

	require.True(t, result.Success())
	retrieved := result.Value()
	assert.Equal(t, original.Name, retrieved.Name)
	assert.Equal(t, original.Value, retrieved.Value)
}

func TestGetJSON_KeyNotFound(t *testing.T) {
	cache := setupTestCache(t)

	type testData struct {
		Name string
	}

	result := getJSON[testData](cache, "nonexistent:key")

	assert.True(t, result.Failure())
	assert.ErrorIs(t, result.Error(), badger.ErrKeyNotFound)
}

func TestGetJSON_InvalidJSON(t *testing.T) {
	cache := setupTestCache(t)

	type testData struct {
		Name string
	}

	cache.db.Update(func(txn *badger.Txn) error {
		return txn.Set([]byte("test:key"), []byte("invalid json"))
	})

	result := getJSON[testData](cache, "test:key")

	assert.True(t, result.Failure())
}

func TestSetJSON_ThenGetJSON_RoundTrip(t *testing.T) {
	cache := setupTestCache(t)

	type complexData struct {
		ID        string
		Name      string
		Value     int
		Active    bool
		Timestamp int64
		Tags      []string
	}

	original := &complexData{
		ID:        "123",
		Name:      "Test",
		Value:     456,
		Active:    true,
		Timestamp: time.Now().UnixMilli(),
		Tags:      []string{"tag1", "tag2"},
	}

	setResult := setJSON(cache, "complex:key", original)
	require.True(t, setResult.Success())

	getResult := getJSON[complexData](cache, "complex:key")
	require.True(t, getResult.Success())

	retrieved := getResult.Value()
	assert.Equal(t, original.ID, retrieved.ID)
	assert.Equal(t, original.Name, retrieved.Name)
	assert.Equal(t, original.Value, retrieved.Value)
	assert.Equal(t, original.Active, retrieved.Active)
	assert.Equal(t, original.Timestamp, retrieved.Timestamp)
	assert.Equal(t, original.Tags, retrieved.Tags)
}

func TestLoadSnapshot_Success(t *testing.T) {
	cache := setupTestCache(t)

	type testItem struct {
		ID   string
		Name string
	}

	items := []testItem{
		{ID: "1", Name: "Item 1"},
		{ID: "2", Name: "Item 2"},
		{ID: "3", Name: "Item 3"},
	}

	fetchFn := func() ([]testItem, error) {
		return items, nil
	}

	keyFn := func(item *testItem) string {
		return "item:" + item.ID
	}

	result := LoadSnapshot(cache, "test_item", fetchFn, keyFn)

	require.True(t, result.Success())
	assert.Equal(t, 3, result.Value())

	for _, item := range items {
		key := keyFn(&item)
		getResult := getJSON[testItem](cache, key)
		require.True(t, getResult.Success())
		assert.Equal(t, item.ID, getResult.Value().ID)
		assert.Equal(t, item.Name, getResult.Value().Name)
	}
}

func TestLoadSnapshot_FetchError(t *testing.T) {
	cache := setupTestCache(t)

	type testItem struct {
		ID string
	}

	expectedError := errors.New("fetch failed")
	fetchFn := func() ([]testItem, error) {
		return nil, expectedError
	}

	keyFn := func(item *testItem) string {
		return "item:" + item.ID
	}

	result := LoadSnapshot(cache, "test_item", fetchFn, keyFn)

	assert.True(t, result.Failure())
	assert.Equal(t, expectedError, result.Error())
}

func TestLoadSnapshot_EmptyList(t *testing.T) {
	cache := setupTestCache(t)

	type testItem struct {
		ID string
	}

	fetchFn := func() ([]testItem, error) {
		return []testItem{}, nil
	}

	keyFn := func(item *testItem) string {
		return "item:" + item.ID
	}

	result := LoadSnapshot(cache, "test_item", fetchFn, keyFn)

	require.True(t, result.Success())
	assert.Equal(t, 0, result.Value())
}

func TestLoadSnapshot_PartialFailure(t *testing.T) {
	cache := setupTestCache(t)

	cache.Close()

	type testItem struct {
		ID string
	}

	items := []testItem{
		{ID: "1"},
		{ID: "2"},
	}

	fetchFn := func() ([]testItem, error) {
		return items, nil
	}

	keyFn := func(item *testItem) string {
		return "item:" + item.ID
	}

	result := LoadSnapshot(cache, "test_item", fetchFn, keyFn)

	require.True(t, result.Success())
	assert.Equal(t, 0, result.Value())
}

func TestCache_MultipleOperations(t *testing.T) {
	cache := setupTestCache(t)

	type testData struct {
		Value string
	}

	for i := 1; i <= 5; i++ {
		data := &testData{Value: string(rune('A' + i - 1))}
		key := string(rune('0' + i))
		result := setJSON(cache, key, data)
		require.True(t, result.Success())
	}

	for i := 1; i <= 5; i++ {
		key := string(rune('0' + i))
		result := getJSON[testData](cache, key)
		require.True(t, result.Success())
		expectedValue := string(rune('A' + i - 1))
		assert.Equal(t, expectedValue, result.Value().Value)
	}
}

func TestCache_UpdateExisting(t *testing.T) {
	cache := setupTestCache(t)

	type testData struct {
		Value string
	}

	initial := &testData{Value: "initial"}
	setJSON(cache, "key", initial)

	updated := &testData{Value: "updated"}
	result := setJSON(cache, "key", updated)
	require.True(t, result.Success())

	getResult := getJSON[testData](cache, "key")
	require.True(t, getResult.Success())
	assert.Equal(t, "updated", getResult.Value().Value)
}

func TestCache_ConcurrentAccess(t *testing.T) {
	cache := setupTestCache(t)

	type testData struct {
		ID    int
		Value string
	}

	done := make(chan bool)
	for i := 0; i < 10; i++ {
		go func(id int) {
			data := &testData{ID: id, Value: "concurrent"}
			setJSON(cache, string(rune('0'+id)), data)
			done <- true
		}(i)
	}

	for i := 0; i < 10; i++ {
		<-done
	}

	for i := 0; i < 10; i++ {
		go func(id int) {
			getJSON[testData](cache, string(rune('0'+id)))
			done <- true
		}(i)
	}

	for i := 0; i < 10; i++ {
		<-done
	}
}
