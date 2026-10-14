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
	envPipeline            = "LAGO_EVENTS_PROCESSOR_PIPELINE"
)

func main() {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	env := utils.GetEnvOrDefault(envEnv, "development")

	// Each pipeline runs in its own deployment, so a catalog failure or backlog
	// never holds back the subscription events.
	pipeline := cache.Pipeline(utils.GetEnvOrDefault(envPipeline, string(cache.PipelineEvents)))
	if pipeline != cache.PipelineEvents && pipeline != cache.PipelineCatalogEvents {
		panic(fmt.Sprintf("%s must be %q or %q, got %q", envPipeline, cache.PipelineEvents, cache.PipelineCatalogEvents, pipeline))
	}

	logLevel := slog.LevelInfo
	if env == "development" {
		logLevel = slog.LevelDebug
	}

	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: logLevel,
	})).With("service", "post_process", "pipeline", string(pipeline))
	slog.SetDefault(logger)

	setupGracefulShutdown(cancel)

	tracerProvider := tracing.InitTracerProvider()
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
			DebeziumTopicPrefix: os.Getenv(envDebeziumTopicPrefix),
			Pipeline:            pipeline,
		})
		if err != nil {
			utils.LogAndPanic(err, "Error creating the cache")
		}
		defer memCache.Close()

		memCache.LoadInitialSnapshot()
		if err := memCache.ConsumeChanges(); err != nil {
			utils.LogAndPanic(err, "Error starting cache consumers")
		}
	}

	config := &processors.Config{
		TracerProvider: tracerProvider,
		Cache:          memCache,
	}

	// start processing events & loop forever
	if pipeline == cache.PipelineCatalogEvents {
		processors.StartProcessingCatalogEvents(ctx, config)
	} else {
		processors.StartProcessingEvents(ctx, config)
	}
}

func setupGracefulShutdown(cancel context.CancelFunc) {
	signChan := make(chan os.Signal, 1)
	signal.Notify(signChan, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		sig := <-signChan
		slog.Info("Received shutdown signal", slog.String("signal", sig.String()))
		cancel()
	}()
}
