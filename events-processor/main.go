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
	"gopkg.in/DataDog/dd-trace-go.v1/ddtrace/tracer"

	tracerConfig "github.com/getlago/lago/events-processor/config"
	"github.com/getlago/lago/events-processor/processors"
)

const (
	envEnv                      = "ENV"
	envSentryDsn                = "SENTRY_DSN"
	envOtelExporterOtlpEndpoint = "OTEL_EXPORTER_OTLP_ENDPOINT"
	envOtelInsecure             = "OTEL_INSECURE"
	envOtelServiceName          = "OTEL_SERVICE_NAME"

	// Datadog environment variable
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

	if os.Getenv(envDatadogAgentHost) != "" {
		initDatadog(logger)
		defer tracer.Stop()
	}

	otelEndpoint := os.Getenv(envOtelExporterOtlpEndpoint)
	if otelEndpoint != "" {
		telemetryCfg := tracerConfig.TracerConfig{
			ServiceName: os.Getenv(envOtelServiceName),
			EndpointURL: otelEndpoint,
			Insecure:    os.Getenv(envOtelInsecure),
		}
		tracerConfig.InitOTLPTracer(telemetryCfg)
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

func setupGracefulShutdown(cancel context.CancelFunc, logger *slog.Logger) {
	signChan := make(chan os.Signal, 1)
	signal.Notify(signChan, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		sig := <-signChan
		logger.Info("Received shutdown signal", slog.String("signal", sig.String()))
		cancel()
	}()
}

func initDatadog(logger *slog.Logger) {
	serviceName := os.Getenv(envDatadogService)
	if serviceName == "" {
		serviceName = "lago-events-processor"
	}

	env := os.Getenv(envEnv)
	if env == "" {
		env = "development"
	}

	options := []tracer.StartOption{
		tracer.WithServiceName(serviceName),
		tracer.WithEnv(env),
	}
	// TODO Fetch version

	agentHost := os.Getenv(envDatadogAgentHost)
	agentPort := os.Getenv(envDatadogAgentPort)
	if agentPort == "" {
		agentPort = "8126"
	}
	options = append(options, tracer.WithAgentAddr(fmt.Sprintf("%s:%s", agentHost, agentPort)))

	tracer.Start(options...)
	logger.Info("Datadog tracer started",
		slog.String("service", serviceName),
	)
}
