package models

import (
	"context"
	"fmt"

	"github.com/getlago/lago/events-processor/config/database"
	"github.com/getlago/lago/events-processor/config/redis"
	"github.com/getlago/lago/events-processor/utils"
)

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

func (store *FlagStore) Flag(value string) error {
	result := store.db.Client.SAdd(store.context, store.name, fmt.Sprintf("%s", value))
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
	DeleteKey(key string) utils.Result[bool]
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

func (store *CacheStore) DeleteKey(key string) utils.Result[bool] {
	res := store.db.Client.Del(store.context, key)
	if err := res.Err(); err != nil {
		return utils.FailedBoolResult(err)
	}

	return utils.SuccessResult(true)
}
