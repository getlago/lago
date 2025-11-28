package tracing

import (
	"context"
	"log/slog"

	"github.com/twmb/franz-go/pkg/kgo"
	ddtracer "gopkg.in/DataDog/dd-trace-go.v1/ddtrace/tracer"
)

// DatadogSpan implements the Span interface.
type DatadogSpan struct {
	span ddtracer.Span
	ctx  context.Context
}

func (s *DatadogSpan) SetAttribute(key string, value any) {
	s.span.SetTag(key, value)
}

func (s *DatadogSpan) SetAttributes(attributes map[string]any) {
	for k, v := range attributes {
		s.span.SetTag(k, v)
	}
}

func (s *DatadogSpan) SetError(err error) {
	s.span.SetTag("error", true)
	s.span.SetTag("error.msg", err.Error())
	s.span.SetTag("error.type", "error")
}

func (s *DatadogSpan) End() {
	s.span.Finish()
}

func (s *DatadogSpan) GetContext() context.Context {
	return s.ctx
}

// DatadogTracer implements the Tracer interface
type DatadogTracer struct {
	serviceName string
}

func NewDatadogTracer(serviceName string) *DatadogTracer {
	return &DatadogTracer{serviceName: serviceName}
}

func (t *DatadogTracer) StartSpan(ctx context.Context, operationName string, opts ...SpanOption) Span {
	config := &SpanConfig{}
	for _, opt := range opts {
		opt(config)
	}

	ddOpts := []ddtracer.StartSpanOption{
		ddtracer.ServiceName(t.serviceName),
	}

	span, spanCtx := ddtracer.StartSpanFromContext(ctx, operationName, ddOpts...)

	if config.Tags != nil {
		for k, v := range config.Tags {
			span.SetTag(k, v)
		}
	}

	if config.Attributes != nil {
		for k, v := range config.Attributes {
			span.SetTag(k, v)
		}
	}

	return &DatadogSpan{span: span, ctx: spanCtx}
}

// DatadogTracerProvider implements the TracerProvider interface
type DatadogTracerProvider struct {
	options TracerProviderOptions
}

func (p *DatadogTracerProvider) GetOptions() TracerProviderOptions {
	return p.options
}

func (p *DatadogTracerProvider) Stop() {
	ddtracer.Stop()
}

func (p *DatadogTracerProvider) InitTracer(serviceName string) Tracer {
	return NewDatadogTracer(serviceName)
}

// Hooks returns the kgo hooks for Datadog instrumentation
func (p *DatadogTracerProvider) GetKafkaHooks() []kgo.Hook {
	return []kgo.Hook{} // TODO(datadog): implement
}

func NewDatadogTracerProvider(logger *slog.Logger, opts TracerProviderOptions) *DatadogTracerProvider {
	options := []ddtracer.StartOption{
		ddtracer.WithServiceName(opts.ServiceName),
		ddtracer.WithEnv(opts.Env),
	}

	options = append(options, ddtracer.WithAgentAddr(opts.ProviderURL))

	ddtracer.Start(options...)
	logger.Info("Datadog tracer started",
		slog.String("service", opts.ServiceName),
	)

	return &DatadogTracerProvider{options: opts}
}
