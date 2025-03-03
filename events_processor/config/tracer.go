package tracer

import (
	"context"
	"log"
	"strings"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/trace"
	"google.golang.org/grpc/credentials"
)

type TracerConfig struct {
	ServiceName string
	EndpointURL string
	Insecure    string
}

func (tc TracerConfig) UseSecureMode() bool {
	return !(strings.ToLower(tc.Insecure) == "false" || tc.Insecure == "0" || strings.ToLower(tc.Insecure) == "f")
}

func GetTracerSpan(ctx context.Context, tracerName string, name string) trace.Span {
	tracer := otel.GetTracerProvider().Tracer(tracerName)
	_, span := tracer.Start(ctx, name)
	return span
}

func InitOTLPTracer(cfg TracerConfig) func(context.Context) error {
	var secureOption otlptracegrpc.Option

	if cfg.UseSecureMode() {
		secureOption = otlptracegrpc.WithTLSCredentials(credentials.NewClientTLSFromCert(nil, ""))
	} else {
		secureOption = otlptracegrpc.WithInsecure()
	}

	exporter, err := otlptrace.New(
		context.Background(),
		otlptracegrpc.NewClient(
			secureOption,
			otlptracegrpc.WithEndpoint(cfg.EndpointURL),
		),
	)

	if err != nil {
		log.Fatalf("Failed to create exporter: %v", err)
	}

	resources, err := resource.New(
		context.Background(),
		resource.WithAttributes(
			attribute.String("service.name", cfg.ServiceName),
			attribute.String("library.language", "go"),
		),
	)

	if err != nil {
		log.Fatalf("Could not set resource: %v", err)
	}

	otel.SetTracerProvider(
		sdktrace.NewTracerProvider(
			sdktrace.WithSampler(sdktrace.AlwaysSample()),
			sdktrace.WithBatcher(exporter),
			sdktrace.WithResource(resources),
		),
	)

	return exporter.Shutdown
}
