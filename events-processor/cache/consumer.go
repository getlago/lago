package cache

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"

	"github.com/dgraph-io/badger/v4"
	"github.com/getlago/lago/events-processor/utils"
	"github.com/google/uuid"
	"github.com/twmb/franz-go/pkg/kgo"
)

type ConsumerConfig[T any] struct {
	Topic        string
	ModelName    string
	IsDeleted    func(*T) bool
	GetKey       func(*T) string
	GetID        func(*T) string
	GetUpdatedAt func(*T) int64
	GetCached    func(*T) utils.Result[*T]
	SetCache     func(*T) utils.Result[bool]
}

func startGenericConsumer[T any](ctx context.Context, cache *Cache, config ConsumerConfig[T]) error {
	groupID := fmt.Sprintf("lago_evt_proc_che_%s_%s", config.ModelName, uuid.New().String())

	client, err := kgo.NewClient(
		kgo.SeedBrokers("redpanda:9092"),
		kgo.ConsumerGroup(groupID),
		kgo.ConsumeTopics(config.Topic),
		kgo.DisableAutoCommit(),
	)
	if err != nil {
		return err
	}

	cache.logger.Info(
		"Starting consumer",
		slog.String("model", config.ModelName),
		slog.String("topic", config.Topic),
		slog.String("group_id", groupID),
	)

	cache.wg.Add(1)
	go func() {
		defer cache.wg.Done()
		defer client.Close()

		for {
			select {
			case <-ctx.Done():
				cache.logger.Info("Context canceled, stopping consumer", slog.String("model", config.ModelName))
				return
			default:
			}

			fetches := client.PollFetches(ctx)
			if fetches.IsClientClosed() {
				cache.logger.Info("Consumer closed", slog.String("model", config.ModelName))
				return
			}

			if err := fetches.Err(); err != nil {
				if ctx.Err() != nil {
					cache.logger.Info("Context canceled during fetch", slog.String("model", config.ModelName))
					return
				}
				cache.logger.Error("Fetch error", slog.String("model", config.ModelName), slog.String("error", err.Error()))
				utils.CaptureError(err)
				continue
			}

			fetches.EachRecord(func(record *kgo.Record) {
				if ctx.Err() != nil {
					return
				}
				processRecord(cache, record, config)
			})

			if err := client.CommitUncommittedOffsets(ctx); err != nil && ctx.Err() == nil {
				cache.logger.Error("Failed to commit offsets", slog.String("model", config.ModelName), slog.String("error", err.Error()))
			}
		}
	}()

	return nil
}

func processRecord[T any](cache *Cache, record *kgo.Record, config ConsumerConfig[T]) {
	var model T
	if err := json.Unmarshal(record.Value, &model); err != nil {
		cache.logger.Error(
			"Failed to unmarshal",
			slog.String("model", config.ModelName),
			slog.String("error", err.Error()),
			slog.String("topic", record.Topic),
		)
		utils.CaptureError(err)
		return
	}

	key := config.GetKey(&model)

	if config.IsDeleted(&model) {
		existingRes := config.GetCached(&model)
		if existingRes.Failure() {
			return
		}

		existing := existingRes.Value()
		if config.GetID(existing) != config.GetID(&model) {
			cache.logger.Debug(
				"ID mismatch - skipping delete",
				slog.String("model", config.ModelName),
				slog.String("key", key),
			)
			return
		}

		if err := cache.db.Update(func(txn *badger.Txn) error {
			return txn.Delete([]byte(key))
		}); err != nil {
			cache.logger.Error(
				"Failed to delete from cache",
				slog.String("model", config.ModelName),
				slog.String("key", key),
				slog.String("error", err.Error()),
			)
			utils.CaptureError(err)
		} else {
			cache.logger.Debug(
				"Cache entry deleted",
				slog.String("model", config.ModelName),
				slog.String("key", key),
			)
		}

		return
	}

	existingRes := config.GetCached(&model)
	if existingRes.Success() {
		existing := existingRes.Value()
		fmt.Printf("existing: %v\n", existing)
		if config.GetUpdatedAt(existing) >= config.GetUpdatedAt(&model) {
			cache.logger.Debug(
				"Skipping update - cached version newer or equal",
				slog.String("model", config.ModelName),
				slog.String("key", key),
				slog.Int64("cached_updated_at", config.GetUpdatedAt(existing)),
				slog.Int64("message_updated_at", config.GetUpdatedAt(&model)),
			)
			return
		}
	}

	res := config.SetCache(&model)
	if res.Failure() {
		cache.logger.Error(
			"Failed to update cache from stream",
			slog.String("model", config.ModelName),
			slog.String("key", key),
			slog.String("error", res.ErrorMsg()),
		)
		utils.CaptureErrorResult(res)
	} else {
		cache.logger.Debug(
			"Cache updated from stream",
			slog.String("model", config.ModelName),
			slog.String("key", key),
			slog.Int64("updated_at", config.GetUpdatedAt(&model)),
		)
	}
}
