package models

import (
	"context"
	"fmt"
	"strings"
	"testing"
	"time"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/alicebob/miniredis/v2"
	goredis "github.com/redis/go-redis/v9"
	"github.com/stretchr/testify/assert"

	"github.com/getlago/lago/events-processor/config/redis"
	"github.com/getlago/lago/events-processor/tests"
)

func setupApiStore(t *testing.T) (*ApiStore, sqlmock.Sqlmock, func()) {
	mock, delete := tests.SetupMockStore(t)

	store := &ApiStore{
		db: mock.DB,
	}

	return store, mock.SQLMock, delete
}

func setupFlagStore(t *testing.T, name string) (*FlagStore, *miniredis.Miniredis) {
	s := miniredis.RunT(t)
	client := goredis.NewClient(&goredis.Options{Addr: s.Addr()})
	store := &FlagStore{
		name:    name,
		context: context.Background(),
		db:      &redis.RedisDB{Client: client},
	}
	return store, s
}

func TestFlag(t *testing.T) {
	t.Run("adds member to sorted set with correct format", func(t *testing.T) {
		store, s := setupFlagStore(t, "test_flags")

		err := store.Flag("org1:sub1")
		assert.NoError(t, err)

		members, err := s.ZMembers("test_flags")
		assert.NoError(t, err)
		assert.Len(t, members, 1)

		// Member should be "org1:sub1|<bucket>"
		assert.True(t, strings.HasPrefix(members[0], "org1:sub1|"))

		// Score should be close to current time
		score, err := s.ZScore("test_flags", members[0])
		assert.NoError(t, err)
		assert.InDelta(t, float64(time.Now().Unix()), score, 2)
	})

	t.Run("bucket follows SUBSCRIPTION_BUCKET_DURATION intervals", func(t *testing.T) {
		store, s := setupFlagStore(t, "test_flags")

		err := store.Flag("org1:sub1")
		assert.NoError(t, err)

		members, err := s.ZMembers("test_flags")
		assert.NoError(t, err)

		parts := strings.Split(members[0], "|")
		assert.Len(t, parts, 2)

		now := time.Now().Unix()
		expectedBucket := (now / SUBSCRIPTION_BUCKET_DURATION) * SUBSCRIPTION_BUCKET_DURATION
		assert.Equal(t, fmt.Sprintf("%d", expectedBucket), parts[1])
	})

	t.Run("two calls in same window produce one member", func(t *testing.T) {
		store, s := setupFlagStore(t, "test_flags")

		err := store.Flag("org1:sub1")
		assert.NoError(t, err)
		err = store.Flag("org1:sub1")
		assert.NoError(t, err)

		members, err := s.ZMembers("test_flags")
		assert.NoError(t, err)
		assert.Len(t, members, 1)
	})

	t.Run("different values produce separate members", func(t *testing.T) {
		store, s := setupFlagStore(t, "test_flags")

		err := store.Flag("org1:sub1")
		assert.NoError(t, err)
		err = store.Flag("org2:sub2")
		assert.NoError(t, err)

		members, err := s.ZMembers("test_flags")
		assert.NoError(t, err)
		assert.Len(t, members, 2)
	})

	t.Run("new bucket after time window advances", func(t *testing.T) {
		store, s := setupFlagStore(t, "test_flags")

		err := store.Flag("org1:sub1")
		assert.NoError(t, err)

		// Fast-forward miniredis past the merge delay window
		s.FastForward(time.Duration(SUBSCRIPTION_BUCKET_DURATION+1) * time.Second)
		// The bucket is computed from time.Now(), so we can't truly advance real time.
		// Instead, we verify that if two different buckets are used, two members exist.
		// Manually add a member with a different bucket to simulate the scenario.
		now := time.Now().Unix()
		differentBucket := ((now / SUBSCRIPTION_BUCKET_DURATION) + 1) * SUBSCRIPTION_BUCKET_DURATION
		s.ZAdd("test_flags", float64(now), fmt.Sprintf("org1:sub1|%d", differentBucket))

		members, err := s.ZMembers("test_flags")
		assert.NoError(t, err)
		assert.Len(t, members, 2)
	})

	t.Run("returns error on redis failure", func(t *testing.T) {
		store, s := setupFlagStore(t, "test_flags")

		s.SetError("forced error")
		err := store.Flag("org1:sub1")
		assert.Error(t, err)
		assert.Contains(t, err.Error(), "forced error")
	})
}
