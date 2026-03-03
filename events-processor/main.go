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

	"github.com/getlago/lago/events-processor/config/tracing"
	"github.com/getlago/lago/events-processor/processors"
	"github.com/getlago/lago/events-processor/utils"
)

const (
	envEnv       = "ENV"
	envSentryDsn = "SENTRY_DSN"
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

	setupGracefulShutdown(cancel)

	tracerProvider := tracing.InitTracerProvider()
	defer tracerProvider.Stop()

	tracing.InitTracer(tracerProvider)

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

	// start processing events & loop forever
	processors.StartProcessingEvents(ctx, &processors.Config{
		TracerProvider: tracerProvider,
	})
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
