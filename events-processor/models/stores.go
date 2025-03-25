package models

import (
	"context"
	"fmt"

	"github.com/getlago/lago/events-processor/config/database"
	"github.com/getlago/lago/events-processor/config/redis"
)

const ERROR_NOT_FOUND string = "record not found"

type ApiStore struct {
	db *database.DB
}

type FlagStore struct {
	name    string
	context context.Context
	db      *redis.RedisDB
}

type Flagger interface {
	Flag(value string) error
}

func NewApiStore(db *database.DB) *ApiStore {
	return &ApiStore{
		db: db,
	}
}

func NewFlagStore(ctx context.Context, redis *redis.RedisDB, name string) *FlagStore {
	return &FlagStore{
		name:    name,
		context: ctx,
		db:      redis,
	}
}

func (store *FlagStore) Flag(value string) error {
	result := store.db.Client.SAdd(store.context, store.name, fmt.Sprintf("%s:1", value))
	if err := result.Err(); err != nil {
		return err
	}

	return nil
}

func (store *FlagStore) Close() error {
	return store.db.Client.Close()
}
