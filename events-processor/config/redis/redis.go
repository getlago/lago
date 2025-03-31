package redis

import (
	"context"

	"github.com/redis/go-redis/extra/redisotel/v9"
	"github.com/redis/go-redis/v9"
)

type RedisConfig struct {
	Address   string
	Password  string
	DB        int
	UseTracer bool
}

type RedisDB struct {
	Client *redis.Client
}

func NewRedisDB(ctx context.Context, cfg RedisConfig) (*RedisDB, error) {
	redisClient := redis.NewClient(&redis.Options{
		Addr:     cfg.Address,
		Password: cfg.Password,
		DB:       cfg.DB,
	})

	status := redisClient.Ping(ctx)
	if status.Err() != nil {
		return nil, status.Err()
	}

	if cfg.UseTracer {
		if err := redisotel.InstrumentTracing(redisClient); err != nil {
			return nil, err
		}
	}

	store := &RedisDB{
		Client: redisClient,
	}

	return store, nil
}
