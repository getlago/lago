package main

import (
	"context"
	"fmt"
	"log/slog"
	"os"
	"time"

	"github.com/getsentry/sentry-go"

	tracer "github.com/getlago/lago/events-processor/config"
	"github.com/getlago/lago/events-processor/processors"
)

const (
	envEnv                      = "ENV"
	envSentryDsn                = "SENTRY_DSN"
	envOtelExporterOtlpEndpoint = "OTEL_EXPORTER_OTLP_ENDPOINT"
	envOtelInsecure             = "OTEL_INSECURE"
	envOtelServiceName          = "OTEL_SERVICE_NAME"
)

func main() {
	ctx := context.Background()

	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil)).
		With("service", "post_process")
	slog.SetDefault(logger)

	otelEndpoint := os.Getenv(envOtelExporterOtlpEndpoint)
	if otelEndpoint != "" {
		telemetryCfg := tracer.TracerConfig{
			ServiceName: os.Getenv(envOtelServiceName),
			EndpointURL: otelEndpoint,
			Insecure:    os.Getenv(envOtelInsecure),
		}
		tracer.InitOTLPTracer(telemetryCfg)
	}

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

	// start processing events & loop forever
	processors.StartProcessingEvents(ctx, &processors.Config{Logger: logger, UseTelemetry: otelEndpoint != ""})
}
