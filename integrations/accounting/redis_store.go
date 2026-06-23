package accounting

import (
	"context"
	"fmt"
	"time"
)

// RedisCmdable is the minimal subset of a Redis client that RedisStore needs.
// The production adapter wraps a real client (e.g. github.com/redis/go-redis) in
// a handful of lines (see README.md); tests use an in-memory fake. Keeping the
// dependency behind this interface means this module stays dependency-free and
// the accounting gate runs anywhere without a live Redis.
type RedisCmdable interface {
	// SetNX sets key with the given TTL only if it does not already exist, and
	// reports whether it was set (true == this caller was first).
	SetNX(ctx context.Context, key string, ttl time.Duration) (bool, error)
	// Exists reports whether key is currently present.
	Exists(ctx context.Context, key string) (bool, error)
}

// RedisStore is a durable IdempotencyStore backed by Redis. Keys are namespaced
// with Prefix and expire after TTL. The idempotent target is the backstop for
// the rare "duplicate arrives after the key expired" case, so exactly-once still
// holds end to end.
type RedisStore struct {
	client RedisCmdable
	prefix string
	ttl    time.Duration
}

// NewRedisStore wraps a Redis client. An empty prefix and non-positive ttl fall
// back to sane defaults (30-day retention).
func NewRedisStore(client RedisCmdable, prefix string, ttl time.Duration) *RedisStore {
	if prefix == "" {
		prefix = "lago:acct:idemp:"
	}
	if ttl <= 0 {
		ttl = 30 * 24 * time.Hour
	}
	return &RedisStore{client: client, prefix: prefix, ttl: ttl}
}

func (r *RedisStore) namespaced(key string) string { return r.prefix + key }

// Seen reports whether key was already delivered.
func (r *RedisStore) Seen(ctx context.Context, key string) (bool, error) {
	ok, err := r.client.Exists(ctx, r.namespaced(key))
	if err != nil {
		return false, fmt.Errorf("redis exists: %w", err)
	}
	return ok, nil
}

// Record marks key as delivered (atomic SetNX with TTL).
func (r *RedisStore) Record(ctx context.Context, key string) error {
	if _, err := r.client.SetNX(ctx, r.namespaced(key), r.ttl); err != nil {
		return fmt.Errorf("redis setnx: %w", err)
	}
	return nil
}
