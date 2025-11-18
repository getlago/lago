package tracing

import (
	"context"
	"fmt"
	"log/slog"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/codes"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	oteltrace "go.opentelemetry.io/otel/trace"
	"google.golang.org/grpc/credentials"
)

// OTelSpan implements the Span interface.
type OTelSpan struct {
	span oteltrace.Span
	ctx  context.Context
}

func (s *OTelSpan) SetAttribute(key string, value any) {
	s.span.SetAttributes(convertToOTelAttribute(key, value))
}

func (s *OTelSpan) SetAttributes(attributes map[string]any) {
	attrs := make([]attribute.KeyValue, 0, len(attributes))
	for k, v := range attributes {
		attrs = append(attrs, convertToOTelAttribute(k, v))
	}
	s.span.SetAttributes(attrs...)
}

func (s *OTelSpan) SetTag(key string, value any) {
	s.SetAttribute(key, value)
}

func (s *OTelSpan) SetError(err error) {
	s.span.RecordError(err)
	s.span.SetStatus(codes.Error, err.Error())
}

func (s *OTelSpan) End() {
	s.span.End()
}

func (s *OTelSpan) GetContext() context.Context {
	return s.ctx
}

// OTelTracer implements the Tracer interface
type OTelTracer struct {
	tracerName string
	Exporter   *otlptrace.Exporter
}

func NewOTelTracer(tracerName string) *OTelTracer {
	return &OTelTracer{tracerName: tracerName}
}

func (t *OTelTracer) StartSpan(ctx context.Context, operationName string, opts ...SpanOption) Span {
	config := &SpanConfig{}
	for _, opt := range opts {
		opt(config)
	}

	tracer := otel.GetTracerProvider().Tracer(t.tracerName)
	spanCtx, span := tracer.Start(ctx, operationName)

	if config.Attributes != nil {
		attrs := make([]attribute.KeyValue, 0, len(config.Attributes))
		for k, v := range config.Attributes {
			attrs = append(attrs, convertToOTelAttribute(k, v))
		}
		span.SetAttributes(attrs...)
	}

	if config.Tags != nil {
		for k, v := range config.Tags {
			span.SetAttributes(convertToOTelAttribute(k, v))
		}
	}

	return &OTelSpan{span: span, ctx: spanCtx}
}

// OTelTracerProvider implements the TracerProvider interface
type OTelTracerProvider struct {
	ctx      context.Context
	logger   *slog.Logger
	exporter *otlptrace.Exporter
}

func (p *OTelTracerProvider) Stop() {
	err := p.exporter.Shutdown(p.ctx)
	if err != nil {
		p.logger.Error("Could not shutdown exporter", slog.String("error", err.Error()))
	}
}

func NewOTelTracerProvider(logger *slog.Logger, opts TracerProviderOptions) *OTelTracerProvider {
	var secureOpt otlptracegrpc.Option
	if opts.SecureMode {
		secureOpt = otlptracegrpc.WithTLSCredentials(credentials.NewClientTLSFromCert(nil, ""))
	} else {
		secureOpt = otlptracegrpc.WithInsecure()
	}

	ctx := context.Background()

	exporter, err := otlptrace.New(
		ctx,
		otlptracegrpc.NewClient(
			secureOpt,
			otlptracegrpc.WithEndpoint(opts.EndPoint),
		),
	)

	if err != nil {
		logger.Error("Could not create open telemetry exporter", slog.String("error", err.Error()))
		return nil
	}

	resources, err := resource.New(
		ctx,
		resource.WithAttributes(
			attribute.String("service.name", opts.ServiceName),
			attribute.String("library.language", "go"),
			attribute.String("deployment.environment", opts.Env),
		),
	)

	if err != nil {
		logger.Error("Could not set open telemetry resource: %v", slog.String("error", err.Error()))
		return nil
	}

	otel.SetTracerProvider(
		sdktrace.NewTracerProvider(
			sdktrace.WithSampler(sdktrace.AlwaysSample()),
			sdktrace.WithBatcher(exporter),
			sdktrace.WithResource(resources),
		),
	)

	return &OTelTracerProvider{
		ctx:      ctx,
		logger:   logger,
		exporter: exporter,
	}
}

func convertToOTelAttribute(key string, value any) attribute.KeyValue {
	switch v := value.(type) {
	case string:
		return attribute.String(key, v)
	case int:
		return attribute.Int(key, v)
	case int64:
		return attribute.Int64(key, v)
	case float64:
		return attribute.Float64(key, v)
	case bool:
		return attribute.Bool(key, v)
	default:
		return attribute.String(key, fmt.Sprintf("%v", v))
	}
}
