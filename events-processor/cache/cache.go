package cache

import (
	"context"
	"fmt"
	"log/slog"
	"os"

	"github.com/dgraph-io/badger/v4"
	"github.com/getlago/lago/events-processor/config/database"
	"github.com/getlago/lago/events-processor/utils"
)

type Cache struct {
	ctx *context.Context
	db *badger.DB
	logger *slog.Logger
}

type CacheConfig struct {
	Context context.Context
	Logger *slog.Logger
}

func NewCache(config CacheConfig) (*Cache, error) {
	opts := badger.DefaultOptions("").WithInMemory(true)
	opts.Logger = nil

	logger := config.Logger.With("pkg", "cache")

	db, err := badger.Open(opts)
	if err != nil {
		return nil, fmt.Errorf("failed to open badger db: %w", err)
	}

	return &Cache {
		db: db,
		logger: logger,
	}, nil
}

func (c *Cache) Close() error {
	return c.db.Close()
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

	c.LoadBillableMetricsSnapshot(db.Connection)
	c.LoadSubscriptionsSnapshot(db.Connection)
}

