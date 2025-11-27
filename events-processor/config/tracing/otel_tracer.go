package tracing

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/twmb/franz-go/pkg/kgo"
	"github.com/twmb/franz-go/plugin/kotel"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/codes"
	"go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetricgrpc"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/sdk/metric"
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
	meter    *otlpmetricgrpc.Exporter
	options  TracerProviderOptions
}

func (p *OTelTracerProvider) Stop() {
	err := p.exporter.Shutdown(p.ctx)
	if err != nil {
		p.logger.Error("Could not shutdown exporter", slog.String("error", err.Error()))
	}

	err = p.meter.Shutdown(p.ctx)
	if err != nil {
		p.logger.Error("Could not shutdown meter", slog.String("error", err.Error()))
	}
}

func (p *OTelTracerProvider) GetOptions() TracerProviderOptions {
	return p.options
}

func (p *OTelTracerProvider) InitTracer(serviceName string) Tracer {
	return NewOTelTracer(serviceName)
}

func (p *OTelTracerProvider) GetKafkaHooks() []kgo.Hook {
	tracerProvider := otel.GetTracerProvider()
	tracerOpts := []kotel.TracerOpt{
		kotel.TracerProvider(tracerProvider),
		kotel.TracerPropagator(propagation.NewCompositeTextMapPropagator(propagation.TraceContext{})),
	}
	tracer := kotel.NewTracer(tracerOpts...)

	meterProvider := otel.GetMeterProvider()
	meterOpts := []kotel.MeterOpt{
		kotel.MeterProvider(meterProvider),
	}
	meter := kotel.NewMeter(meterOpts...)

	kotelOpts := []kotel.Opt{
		kotel.WithTracer(tracer),
		kotel.WithMeter(meter),
	}

	kotelService := kotel.NewKotel(kotelOpts...)
	return kotelService.Hooks()
}

func NewOTelTracerProvider(logger *slog.Logger, opts TracerProviderOptions) *OTelTracerProvider {
	ctx := context.Background()
	exporter, err := initTracerExporter(ctx, opts)
	if err != nil {
		logger.Error("Could not create open telemetry exporter", slog.String("error", err.Error()))
		return nil
	}

	meter, err := initMeterExporter(ctx, opts)
	if err != nil {
		logger.Error("Could not create open telemetry meter", slog.String("error", err.Error()))
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

	otel.SetMeterProvider(
		metric.NewMeterProvider(
			metric.WithReader(
				metric.NewPeriodicReader(meter, metric.WithInterval(60*time.Second)),
			),
			metric.WithResource(resources),
		),
	)

	return &OTelTracerProvider{
		ctx:      ctx,
		logger:   logger,
		exporter: exporter,
		meter:    meter,
		options:  opts,
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

func initTracerExporter(ctx context.Context, opts TracerProviderOptions) (*otlptrace.Exporter, error) {
	var secureOpt otlptracegrpc.Option
	if opts.SecureMode {
		secureOpt = otlptracegrpc.WithTLSCredentials(credentials.NewClientTLSFromCert(nil, ""))
	} else {
		secureOpt = otlptracegrpc.WithInsecure()
	}

	exporter, err := otlptrace.New(
		ctx,
		otlptracegrpc.NewClient(
			secureOpt,
			otlptracegrpc.WithEndpoint(opts.ProviderURL),
		),
	)

	return exporter, err
}

func initMeterExporter(ctx context.Context, opts TracerProviderOptions) (*otlpmetricgrpc.Exporter, error) {
	var secureOpt otlpmetricgrpc.Option
	if opts.SecureMode {
		secureOpt = otlpmetricgrpc.WithTLSCredentials(credentials.NewClientTLSFromCert(nil, ""))
	} else {
		secureOpt = otlpmetricgrpc.WithInsecure()
	}

	exporter, err := otlpmetricgrpc.New(
		ctx,
		secureOpt,
		otlpmetricgrpc.WithEndpoint(opts.ProviderURL),
	)

	return exporter, err
}
