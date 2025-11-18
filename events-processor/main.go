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

	envTracingProvider = "TRACING_PROVIDER"

	// OpenTelemetry environment variables
	envOtelExporterOtlpEndpoint = "OTEL_EXPORTER_OTLP_ENDPOINT"
	envOtelInsecure             = "OTEL_INSECURE"
	envOtelServiceName          = "OTEL_SERVICE_NAME"

	// Datadog environment variables
	envDatadogEnabled   = "DD_TRACE_ENABLED"
	envDatadogAgentHost = "DD_AGENT_HOST"
	envDatadogAgentPort = "DD_TRACE_AGENT_PORT"
	envDatadogService   = "DD_SERVICE_NAME"
)

func main() {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil)).
		With("service", "post_process")
	slog.SetDefault(logger)

	setupGracefulShutdown(cancel, logger)

	tracingProvider := findTracingProvider()
	tracerProviderOpts := initTracerProviderOpts(tracingProvider)

	tracerProvider := tracing.InitTracerProvider(
		tracingProvider,
		logger,
		tracerProviderOpts,
	)
	defer tracerProvider.Stop()

	tracing.InitTracer(tracingProvider, tracerProviderOpts.ServiceName)

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
	processors.StartProcessingEvents(ctx, &processors.Config{
		Logger:       logger,
		UseTelemetry: tracingProvider == tracing.OTelProvider, // TODO: Check for datadog
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

func findTracingProvider() tracing.TracingProvider {
	provider := os.Getenv(envTracingProvider)

	switch provider {
	case "datadog":
		return tracing.DatadogProvider
	case "opentelemetry":
		return tracing.OTelProvider
	default:
		if utils.GetEnvAsBool(envDatadogEnabled, false) {
			return tracing.DatadogProvider
		}
		if os.Getenv(envOtelExporterOtlpEndpoint) != "" {
			return tracing.OTelProvider
		}
		return tracing.EmptyProvider
	}
}

func initTracerProviderOpts(tracingProvider tracing.TracingProvider) tracing.TracerProviderOptions {
	env := os.Getenv(envEnv)
	if env == "" {
		env = "development"
	}

	opts := tracing.TracerProviderOptions{
		Env:         env,
		ServiceName: "lago-events-processor",
	}
	// TODO: fetch version

	switch tracingProvider {
	case tracing.OTelProvider:
		serviceName := os.Getenv(envOtelServiceName)
		if serviceName != "" {
			opts.ServiceName = serviceName
		}
		opts.EndPoint = os.Getenv(envOtelExporterOtlpEndpoint)

		insecure := utils.GetEnvAsBool(envOtelInsecure, false)
		opts.SecureMode = !insecure

	case tracing.DatadogProvider:
		serviceName := os.Getenv(envDatadogService)
		if serviceName != "" {
			opts.ServiceName = serviceName
		}

		host := os.Getenv(envDatadogAgentHost)
		port := utils.GetEnvOrDefault(envDatadogAgentPort, "8126")
		opts.EndPoint = fmt.Sprintf("%s:%s", host, port)
	}

	return opts
}
