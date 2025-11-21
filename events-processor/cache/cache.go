package cache

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"os"
	"sync"
	"time"

	"github.com/dgraph-io/badger/v4"
	"github.com/getlago/lago/events-processor/config/database"
	"github.com/getlago/lago/events-processor/utils"
)

// Cache wraps BadgerDB to provide an in§memory key§value store with JSON serialization
// It manages the lifecycle of cached data and coordinates snapshot loading and CDC consumption.
type Cache struct {
	ctx    context.Context
	db     *badger.DB
	logger *slog.Logger
	wg     sync.WaitGroup
}

// CacheConfig holds the configuration needed to initialize a new Cache instance.
type CacheConfig struct {
	Context context.Context
	Logger  *slog.Logger
}

// NewCache creates and initializes a new in-memory cache instance.
// It configures the database with default options
func NewCache(config CacheConfig) (*Cache, error) {
	opts := badger.DefaultOptions("").WithInMemory(true)
	opts.Logger = nil

	logger := config.Logger.With("pkg", "cache")

	db, err := badger.Open(opts)
	if err != nil {
		return nil, fmt.Errorf("failed to open badger db: %w", err)
	}

	return &Cache{
		db:     db,
		logger: logger,
		ctx:    config.Context,
	}, nil
}

func (c *Cache) Close() error {
	return c.db.Close()
}

func (c *Cache) Wait() {
	c.wg.Wait()
}

func (c *Cache) LoadInitialSnapshot() {
	dbConfig := database.DBConfig{
		Url:      os.Getenv("DATABASE_URL"),
		MaxConns: 10,
	}

	db, err := database.NewConnection(dbConfig)
	if err != nil {
		c.logger.Error("Error connecting to the database", slog.String("error", err.Error()))
		utils.CaptureError(err)
		panic(err.Error())
	}

	var wg sync.WaitGroup
	wg.Add(5)

	go func() {
		defer wg.Done()
		c.LoadBillableMetricsSnapshot(db.Connection)
	}()

	go func() {
		defer wg.Done()
		c.LoadSubscriptionsSnapshot(db.Connection)
	}()

	go func() {
		defer wg.Done()
		c.LoadChargesSnapshot(db.Connection)
	}()

	go func() {
		defer wg.Done()
		c.LoadBillableMetricFiltersSnapshot(db.Connection)
	}()

	go func() {
		defer wg.Done()
		c.LoadChargeFiltersSnapshot(db.Connection)
	}()

	go func() {
		defer wg.Done()
		c.LoadChargeFilterValuesSnapshot(db.Connection)
	}()

	wg.Wait()
}

func (c *Cache) ConsumeChanges() {
	if err := c.StartBillableMetricsConsumer(c.ctx); err != nil {
		c.logger.Error("failed to start billable metrics consumer", slog.String("error", err.Error()))
	}

	if err := c.StartSubscriptionsConsumer(c.ctx); err != nil {
		c.logger.Error("failed to start subscriptions consumer", slog.String("error", err.Error()))
	}

	if err := c.StartChargesConsumer(c.ctx); err != nil {
		c.logger.Error("failed to start charges consumer", slog.String("error", err.Error()))
	}

	if err := c.StartBillableMetricFiltersConsumer(c.ctx); err != nil {
		c.logger.Error("failed to start billable metric filters consumer", slog.String("error", err.Error()))
	}

	if err := c.StartChargeFiltersConsumer(c.ctx); err != nil {
		c.logger.Error("failed to start charge filters consumer", slog.String("error", err.Error()))
	}

	if err := c.StartChargeFilterValuesConsumer(c.ctx); err != nil {
		c.logger.Error("failed to start charge filter values consumer", slog.String("error", err.Error()))
	}

	c.wg.Wait()
}

func setJSON[T any](cache *Cache, key string, value *T) utils.Result[bool] {
	data, err := json.Marshal(value)
	if err != nil {
		return utils.FailedBoolResult(err)
	}

	err = cache.db.Update(func(txn *badger.Txn) error {
		return txn.Set([]byte(key), data)
	})
	if err != nil {
		return utils.FailedBoolResult(err)
	}

	return utils.SuccessResult(true)
}

func delete(cache *Cache, key string) utils.Result[bool] {
	err := cache.db.Update(func(txn *badger.Txn) error {
		return txn.Delete([]byte(key))
	})
	if err != nil {
		return utils.FailedBoolResult(err)
	}

	return utils.SuccessResult(true)
}

// deleteWithTTL schedules a delayed deletion by setting the key with a TTL
// The key will remain accessible with its current value until the TTL expires.
func deleteWithTTL[T any](cache *Cache, key string, value *T, ttl time.Duration) utils.Result[bool] {
	data, err := json.Marshal(value)
	if err != nil {
		return utils.FailedBoolResult(err)
	}

	err = cache.db.Update(func(txn *badger.Txn) error {
		entry := badger.NewEntry([]byte(key), data).WithTTL(ttl)
		return txn.SetEntry(entry)
	})
	if err != nil {
		return utils.FailedBoolResult(err)
	}

	return utils.SuccessResult(true)
}

func getJSON[T any](cache *Cache, key string) utils.Result[*T] {
	var out T
	err := cache.db.View(func(txn *badger.Txn) error {
		item, err := txn.Get([]byte(key))
		if err != nil {
			return err
		}
		return item.Value(func(val []byte) error {
			return json.Unmarshal(val, &out)
		})
	})

	if err == badger.ErrKeyNotFound {
		return utils.FailedResult[*T](err).NonCapturable().NonRetryable()
	}
	if err != nil {
		return utils.FailedResult[*T](err)
	}

	return utils.SuccessResult(&out)
}

func searchJSON[T any](cache *Cache, prefix string) utils.Result[[]*T] {
	var results []*T

	err := cache.db.View(func(txn *badger.Txn) error {
		it := txn.NewIterator(badger.DefaultIteratorOptions)
		defer it.Close()

		prefixBytes := []byte(prefix)
		for it.Seek(prefixBytes); it.ValidForPrefix(prefixBytes); it.Next() {
			item := it.Item()
			err := item.Value(func(val []byte) error {
				var out T
				if err := json.Unmarshal(val, &out); err != nil {
					return err
				}
				results = append(results, &out)
				return nil
			})
			if err != nil {
				return err
			}
		}
		return nil
	})

	if err != nil {
		return utils.FailedResult[[]*T](err)
	}

	return utils.SuccessResult(results)
}

func LoadSnapshot[T any](
	cache *Cache,
	name string,
	fetchFn func() ([]T, error),
	keyFn func(*T) string,
) utils.Result[int] {
	cache.logger.Info("Starting snapshot load", slog.String("model", name))
	start := time.Now()

	list, err := fetchFn()
	if err != nil {
		return utils.FailedResult[int](err)
	}

	count := 0
	for i := range list {
		item := &list[i]
		key := keyFn(item)
		if res := setJSON(cache, key, item); res.Failure() {
			cache.logger.Error(
				"Failed to cache item",
				slog.String("model", name),
				slog.String("key", key),
				slog.String("error", res.ErrorMsg()),
			)
			utils.CaptureErrorResult(res)
			continue
		}
		count++
	}

	duration := time.Since(start)
	cache.logger.Info(
		"Completed snapshot load",
		slog.String("model", name),
		slog.Int("count", count),
		slog.Int64("duration_ms", duration.Milliseconds()),
	)

	return utils.SuccessResult(count)
}
