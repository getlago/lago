package tracing

import (
	"context"
)

// Generic tracing span interface
type Span interface {
	SetAttribute(key string, value any)
	SetAttributes(attributes map[string]any)
	SetError(err error)
	End()
	GetContext() context.Context
}

// Generic tracer interface
type Tracer interface {
	StartSpan(ctx context.Context, operationName string, opts ...SpanOption) Span
}

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

type TracerProvider interface {
	Stop()
}

type TracerProviderOptions struct {
	Env         string
	ServiceName string
	EndPoint    string
	SecureMode  bool
}
