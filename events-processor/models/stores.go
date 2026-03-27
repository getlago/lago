package models

import (
	"context"
	"fmt"
	"time"

	goredis "github.com/redis/go-redis/v9"

	"github.com/getlago/lago/events-processor/config/database"
	"github.com/getlago/lago/events-processor/config/redis"
	"github.com/getlago/lago/events-processor/utils"
)

const EXPIRATION_TIME = 15 * time.Second
const CLICKHOUSE_MERGE_DELAY int64 = 15

type ApiStore struct {
	db *database.DB
}

func NewApiStore(db *database.DB) *ApiStore {
	return &ApiStore{
		db: db,
	}
}

type FlagStore struct {
	name    string
	context context.Context
	db      *redis.RedisDB
}

type Flagger interface {
	Flag(value string) error
}

func NewFlagStore(ctx context.Context, redis *redis.RedisDB, name string) *FlagStore {
	return &FlagStore{
		name:    name,
		context: ctx,
		db:      redis,
	}
}

// Flag adds a subscription to the sorted set for delayed refresh.
// The member key includes a time bucket (value|bucket) so that events within
// the same CLICKHOUSE_MERGE_DELAY window share a member — ZADD overwrites the
// score to the latest event, waiting after the last event in that window.
// Once the window elapses, new events create a new member, ensuring the
// previous one ages out and gets picked up by the consumer (no starvation).
func (store *FlagStore) Flag(value string) error {
	now := time.Now().Unix()

	// Calculate the bucket (time window) for the event
	bucket := (now / CLICKHOUSE_MERGE_DELAY) * CLICKHOUSE_MERGE_DELAY

	result := store.db.Client.ZAdd(store.context, store.name, goredis.Z{
		Score:  float64(now),
		Member: fmt.Sprintf("%s|%d", value, bucket),
	})
	if err := result.Err(); err != nil {
		return err
	}

	return nil
}

func (store *FlagStore) Close() error {
	return store.db.Client.Close()
}

type Cacher interface {
	Close() error
	ExpireKey(key string) utils.Result[bool]
}

type CacheStore struct {
	context context.Context
	db      *redis.RedisDB
}

func NewCacheStore(ctx context.Context, redis *redis.RedisDB) *CacheStore {
	return &CacheStore{
		context: ctx,
		db:      redis,
	}
}

func (store *CacheStore) Close() error {
	return store.db.Client.Close()
}

func (store *CacheStore) ExpireKey(key string) utils.Result[bool] {
	// Uses Expire command rather than Del to take clickhouse propagation time into account
	res := store.db.Client.Expire(store.context, key, EXPIRATION_TIME)
	if err := res.Err(); err != nil {
		return utils.FailedBoolResult(err)
	}

	return utils.SuccessResult(true)
}
