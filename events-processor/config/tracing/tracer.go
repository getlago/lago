package tracing

import (
	"context"
	"log/slog"
	"sync"
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
)

func InitTracerProvider(tracingProvider TracingProvider, logger *slog.Logger, opts TracerProviderOptions) TracerProvider {
	var provider TracerProvider

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

func InitTracer(provider TracingProvider, serviceName string) Tracer {
	once.Do(func() {
		switch provider {
		case OTelProvider:
			globalTracer = NewOTelTracer(serviceName)
		case DatadogProvider:
			globalTracer = NewDatadogTracer(serviceName)
		case EmptyProvider:
			globalTracer = NewEmptyTracer()
		}
	})

	return globalTracer
}

func GetTracer() Tracer {
	if globalTracer == nil {
		globalTracer = NewEmptyTracer()
	}
	return globalTracer
}

func StartSpan(ctx context.Context, operationName string, opts ...SpanOption) Span {
	return GetTracer().StartSpan(ctx, operationName, opts...)
}
