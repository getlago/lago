package tracing

import (
	"context"

	"github.com/twmb/franz-go/pkg/kgo"
)

// Generic tracing span interface
type Span interface {
	// SetAttribute sets a key-value pair as an attribute on the span.
	SetAttribute(key string, value any)

	// SetAttributes sets multiple key-value pairs as attributes on the span.
	SetAttributes(attributes map[string]any)

	// SetError sets all error attributes on the span.
	SetError(err error)

	//End terminates the span.
	End()

	//GetContext returns the context associated with the span.
	GetContext() context.Context
}

// Generic tracer interface
type Tracer interface {
	//StartSpan starts a new span with the given operation name and options.
	StartSpan(ctx context.Context, operationName string, opts ...SpanOption) Span
}

// SpanOption is a function that configures a Span.
type SpanOption func(*SpanConfig)

type SpanConfig struct {
	Tags       map[string]any
	Attributes map[string]any
	Parent     Span
}

func WithTag(key string, value any) SpanOption {
	return func(cfg *SpanConfig) {
		if cfg.Tags == nil {
			cfg.Tags = make(map[string]any)
		}
		cfg.Tags[key] = value
	}
}

// Generic tracer provider interface
type TracerProvider interface {
	// Stop stops the tracer provider.
	Stop()

	// GetOptions returns the options used to configure the tracer provider.
	GetOptions() TracerProviderOptions

	// InitTracer initializes a new tracer for the provider with the given service name.
	InitTracer(serviceName string) Tracer

	// GetKafkaHooks returns the Kafka hooks for the provider.
	GetKafkaHooks() []kgo.Hook
}

// TracerProviderOptions is a struct that holds the options for configuring a tracer provider.
type TracerProviderOptions struct {
	// Current environment
	Env string

	// Service Name
	ServiceName string

	// Provider url or endpoint
	ProviderURL string

	// Turn On/Off Secure Mode
	SecureMode bool

	// Turn On/Off Kafka Tracing
	KafkaTracing bool

	// Provider type
	TracingProvider TracingProvider
}
