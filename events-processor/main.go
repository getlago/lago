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
	"github.com/getlago/lago/events-processor/config/tracing"
	"github.com/getlago/lago/events-processor/processors"
	"github.com/getlago/lago/events-processor/utils"
	"github.com/getsentry/sentry-go"
)

var (
	ctx      context.Context
	logger   *slog.Logger
	memCache *cache.Cache
)

const (
	envEnv       = "ENV"
	envSentryDsn = "SENTRY_DSN"
)

func main() {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil)).
		With("service", "post_process")
	slog.SetDefault(logger)

	setupGracefulShutdown(cancel, logger)

	tracerProvider := tracing.InitTracerProvider(logger)
	defer tracerProvider.Stop()

	tracing.InitTracer(tracerProvider)

	err := sentry.Init(sentry.ClientOptions{
		Dsn:              os.Getenv(envSentryDsn),
		Environment:      os.Getenv(envEnv),
		Debug:            false,
		AttachStacktrace: true,
	})

	if err != nil {
		fmt.Printf("Sentry initialization failed: %v\n", err)
	}

	defer sentry.Flush(2 * time.Second)

	memCache, err = cache.NewCache(cache.CacheConfig{
		Context: ctx,
		Logger:  logger,
	})
	if err != nil {
		logger.Error("Error creating the cache", slog.String("error", err.Error()))
		utils.CaptureError(err)
		panic(err.Error())
	}

	memCache.LoadInitialSnapshot()
	memCache.ConsumeChanges()

	// start processing events & loop forever
	processors.StartProcessingEvents(ctx, &processors.Config{
		Logger:         logger,
		TracerProvider: tracerProvider,
		Cache:          memCache,
	})
}

func setupGracefulShutdown(cancel context.CancelFunc, logger *slog.Logger) {
	signChan := make(chan os.Signal, 1)
	signal.Notify(signChan, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		sig := <-signChan
		logger.Info("Received shutdown signal", slog.String("signal", sig.String()))
		cancel()
	}()
}
