package main

import (
	"context"
	"fmt"
	"log/slog"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/getlago/lago/events-processor/cache"
	"github.com/getlago/lago/events-processor/utils"
	"github.com/getsentry/sentry-go"
)

var (
	logger *slog.Logger
	memCache *cache.Cache
)

func main() {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		sig := <-sigChan
		logger.Info(
			"Received shutdown signal",
			slog.String("signal", sig.String()),
		)
		cancel()
		memCache.Close()
	}()

	logger = slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelDebug})).
		With("service", "lago-events-processor")
	slog.SetDefault(logger)

	err := sentry.Init(sentry.ClientOptions{
		Dsn:              os.Getenv("SENTRY_DSN"),
		Environment:      os.Getenv("ENV"),
		Debug:            false,
		AttachStacktrace: true,
	})

	if err != nil {
		fmt.Printf("Sentry initialization failed: %v\n", err)
	}

	defer sentry.Flush(2 * time.Second)

	// Build In Memory Cache
	memCache, err := cache.NewCache(cache.CacheConfig{
		Context: ctx,
		Logger: logger,
	})
	if err != nil {
		logger.Error("Error creating the cache", slog.String("error", err.Error()))
		utils.CaptureError(err)
		panic(err.Error())
	}

	memCache.LoadInitialSnapshot()
	memCache.ConsumeChanges()

	// start processing events & loop forever
	//processors.StartProcessingEvents()
}
