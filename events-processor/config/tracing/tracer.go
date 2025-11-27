package tracing

import (
	"context"
	"fmt"
	"log/slog"
	"os"
	"sync"

	"github.com/getlago/lago/events-processor/utils"
)

var (
	globalTracer Tracer
	once         sync.Once
)

type TracingProvider string

const (
	OTelProvider    TracingProvider = "opentelemetry"
	DatadogProvider TracingProvider = "datadog"
	EmptyProvider   TracingProvider = "none"

	// Environment variables
	envEnv             = "ENV"
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

// Init the tracing provider based on the environment variable
// It will first evaluate the `TRACING_PROVIDER` environment variable
// If nil, it will check for the `DD_TRACE_ENABLED` (datadog)
// and finaly `OTEL_EXPORTER_OTLP_ENDPOINT` (opentelemetry)
// An "Empty" provider will be returned if no provider is found
func InitTracerProvider(logger *slog.Logger) TracerProvider {
	tracingProvider := findTracingProvider(os.Getenv(envTracingProvider))

	var provider TracerProvider
	opts := initTracerProviderOpts(tracingProvider)

	switch tracingProvider {
	case OTelProvider:
		provider = NewOTelTracerProvider(logger, opts)
	case DatadogProvider:
		provider = NewDatadogTracerProvider(logger, opts)
	default:
		provider = &EmptyTracerProvider{}
	}
	return provider
}

// Init the global tracer for the given provider
// This tracer will be set in the globalTracer variable
// and will be returned by calling GetTracer()
func InitTracer(provider TracerProvider) Tracer {
	once.Do(func() {
		globalTracer = provider.InitTracer(provider.GetOptions().ServiceName)
	})

	return globalTracer
}

// Get the current tracer configured for the provider
func GetTracer() Tracer {
	if globalTracer == nil {
		globalTracer = NewEmptyTracer()
	}
	return globalTracer
}

// Start a tracing span
func StartSpan(ctx context.Context, operationName string, opts ...SpanOption) Span {
	return GetTracer().StartSpan(ctx, operationName, opts...)
}

func findTracingProvider(provider string) TracingProvider {
	switch provider {
	case "datadog":
		return DatadogProvider
	case "opentelemetry":
		return OTelProvider
	default:
		if utils.GetEnvAsBool(envDatadogEnabled, false) {
			return DatadogProvider
		}
		if os.Getenv(envOtelExporterOtlpEndpoint) != "" {
			return OTelProvider
		}
		return EmptyProvider
	}
}

func initTracerProviderOpts(tracingProvider TracingProvider) TracerProviderOptions {
	env := os.Getenv(envEnv)
	if env == "" {
		env = "development"
	}

	opts := TracerProviderOptions{
		Env:             env,
		ServiceName:     "lago-events-processor",
		TracingProvider: tracingProvider,
	}
	// TODO: fetch version

	switch tracingProvider {
	case OTelProvider:
		serviceName := os.Getenv(envOtelServiceName)
		if serviceName != "" {
			opts.ServiceName = serviceName
		}
		opts.ProviderURL = os.Getenv(envOtelExporterOtlpEndpoint)

		insecure := utils.GetEnvAsBool(envOtelInsecure, false)
		opts.SecureMode = !insecure

	case DatadogProvider:
		serviceName := os.Getenv(envDatadogService)
		if serviceName != "" {
			opts.ServiceName = serviceName
		}

		host := os.Getenv(envDatadogAgentHost)
		port := utils.GetEnvOrDefault(envDatadogAgentPort, "8126")
		opts.ProviderURL = fmt.Sprintf("%s:%s", host, port)
	}

	return opts
}
