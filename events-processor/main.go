package main

import (
	"context"
	"fmt"
	"log/slog"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/getsentry/sentry-go"

	"github.com/getlago/lago/events-processor/cache"
	"github.com/getlago/lago/events-processor/config/tracing"
	"github.com/getlago/lago/events-processor/processors"
	"github.com/getlago/lago/events-processor/utils"
)

const (
	envEnv                 = "ENV"
	envSentryDsn           = "SENTRY_DSN"
	envUseMemoryCache      = "LAGO_USE_MEMORY_CACHE"
	envDebeziumTopicPrefix = "LAGO_DEBEZIUM_TOPIC_PREFIX"
)

func main() {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	env := utils.GetEnvOrDefault(envEnv, "development")

	logLevel := slog.LevelInfo
	if env == "development" {
		logLevel = slog.LevelDebug
	}

	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: logLevel,
	})).With("service", "post_process")
	slog.SetDefault(logger)

	setupGracefulShutdown(cancel, logger)

	tracerProvider := tracing.InitTracerProvider(logger)
	if tracerProvider == nil {
		slog.Error("Failed to initialize tracer provider, tracing disabled")
	} else {
		defer tracerProvider.Stop()
		tracing.InitTracer(tracerProvider)
	}

	err := sentry.Init(sentry.ClientOptions{
		Dsn:              os.Getenv(envSentryDsn),
		Environment:      env,
		Debug:            false,
		AttachStacktrace: true,
	})

	if err != nil {
		fmt.Printf("Sentry initialization failed: %v\n", err)
	}

	defer sentry.Flush(2 * time.Second)

	var memCache *cache.Cache
	if os.Getenv(envUseMemoryCache) == "true" {
		memCache, err = cache.NewCache(cache.CacheConfig{
			Context:             ctx,
			Logger:              logger,
			DebeziumTopicPrefix: os.Getenv(envDebeziumTopicPrefix),
		})
		if err != nil {
			utils.LogAndPanic(err, "Error creating the cache")
		}
		defer memCache.Close()

		memCache.LoadInitialSnapshot()
		memCache.ConsumeChanges()
	}

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
