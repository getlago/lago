package redis

import (
	"context"
	"crypto/tls"
	"regexp"
	"time"

	"github.com/redis/go-redis/extra/redisotel/v9"
	"github.com/redis/go-redis/v9"
)

type RedisConfig struct {
	Address   string
	Password  string
	DB        int
	UseTracer bool
	UseTLS    bool
}

type RedisDB struct {
	Client *redis.Client
}

func (rc *RedisConfig) AddressAndPort() string {
	re := regexp.MustCompile(`^rediss?://`)
	return re.ReplaceAllString(rc.Address, "")
}

func NewRedisDB(ctx context.Context, cfg RedisConfig) (*RedisDB, error) {
	redisClient := redis.NewClient(&redis.Options{
		Addr:         cfg.AddressAndPort(),
		Password:     cfg.Password,
		DB:           cfg.DB,
		DialTimeout:  5 * time.Second,
		ReadTimeout:  3 * time.Second,
		WriteTimeout: 3 * time.Second,
		PoolSize:     10,
		PoolTimeout:  4 * time.Second,
	})

	if cfg.UseTLS {
		tlsConfig := &tls.Config{
			InsecureSkipVerify: true,
		}

		redisClient.Options().TLSConfig = tlsConfig
	}

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
