package tracing

import (
	"context"
	"log/slog"

	"github.com/DataDog/dd-trace-go/v2/ddtrace/ext"
	ddtracer "github.com/DataDog/dd-trace-go/v2/ddtrace/tracer"
	"github.com/twmb/franz-go/pkg/kgo"
)

// DatadogSpan implements the Span interface.
type DatadogSpan struct {
	span *ddtracer.Span
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
	return []kgo.Hook{
		&datadogProduceHook{serviceName: p.options.ServiceName},
		&datadogConsumeHook{serviceName: p.options.ServiceName},
	}
}

func NewDatadogTracerProvider(logger *slog.Logger, opts TracerProviderOptions) *DatadogTracerProvider {
	options := []ddtracer.StartOption{
		ddtracer.WithService(opts.ServiceName),
		ddtracer.WithEnv(opts.Env),
	}

	options = append(options, ddtracer.WithAgentAddr(opts.ProviderURL))

	ddtracer.Start(options...)
	logger.Info("Datadog tracer started",
		slog.String("service", opts.ServiceName),
	)

	return &DatadogTracerProvider{
		options: opts,
	}
}

// Kafka producer hook for Datadog
type datadogProduceHook struct {
	serviceName string
}

// This hook is called immediatly after "Produce" is called
func (h *datadogProduceHook) OnProduceRecordBuffered(r *kgo.Record) {
	span, ctx := ddtracer.StartSpanFromContext(context.Background(), "kafka.produce")
	span.SetTag(ext.Component, "kafka")
	span.SetTag(ext.SpanType, "producer")
	span.SetTag("kafka.topic", r.Topic)
	span.SetTag("kafka.partition", r.Partition)

	if len(r.Key) > 0 {
		span.SetTag("kafka.key", string(r.Key))
	}

	// Store the span in the record's context for completion later
	if r.Context == nil {
		r.Context = ctx
	} else {
		r.Context = ddtracer.ContextWithSpan(r.Context, span)
	}
}

// This hook is called once a record is queued to be flushed.
func (h *datadogProduceHook) OnProduceRecordUnbuffered(r *kgo.Record, err error) {
	// Finish the span that was started in OnProduceRecordBuffered
	if span, ok := ddtracer.SpanFromContext(r.Context); ok {
		if err != nil {
			span.SetTag("error", true)
			span.SetTag("error.msg", err.Error())
		} else {
			span.SetTag("kafka.offset", r.Offset)
		}

		span.Finish()
	}
}

// Consumer hook for Datadog
type datadogConsumeHook struct {
	serviceName string
}

// This hook is called once a record is ready to be polled.
func (h *datadogConsumeHook) OnFetchRecordBuffered(r *kgo.Record) {
	span, ctx := ddtracer.StartSpanFromContext(context.Background(), "kafka.consume")
	span.SetTag(ext.Component, "kafka")
	span.SetTag(ext.SpanType, "consumer")
	span.SetTag("kafka.topic", r.Topic)
	span.SetTag("kafka.partition", r.Partition)
	span.SetTag("kafka.offset", r.Offset)

	if len(r.Key) > 0 {
		span.SetTag("kafka.key", string(r.Key))
	}

	// Store the span in the record's context
	if r.Context == nil {
		r.Context = ctx
	} else {
		r.Context = ddtracer.ContextWithSpan(r.Context, span)
	}
}

// This hook is called once a record has been processed.
func (h *datadogConsumeHook) OnFetchRecordUnbuffered(r *kgo.Record) {
	// Finish the span when record processing is complete
	if span, ok := ddtracer.SpanFromContext(r.Context); ok {
		span.Finish()
	}
}
