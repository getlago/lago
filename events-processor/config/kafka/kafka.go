package kafka

import (
	"context"
	"log/slog"
	"time"

	"github.com/twmb/franz-go/pkg/kgo"
	"github.com/twmb/franz-go/pkg/sasl/scram"
	"github.com/twmb/franz-go/plugin/kotel"
	"github.com/twmb/franz-go/plugin/kslog"
	"go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetricgrpc"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/trace"
)

const (
	Scram256 string = "SCRAM-SHA-256"
	Scram512 string = "SCRAM-SHA-512"
)

type ServerConfig struct {
	ScramAlgorithm string
	TLS            bool
	Servers        []string
	UseTelemetry   bool
	UserName       string
	Password       string
}

func NewKafkaClient(serverConfig ServerConfig, config []kgo.Opt) (*kgo.Client, error) {
	logger := slog.Default()
	logger = logger.With("component", "kafka")

	opts := []kgo.Opt{
		kgo.SeedBrokers(serverConfig.Servers...),
		kgo.WithLogger(kslog.New(logger)),
	}

	if len(config) > 0 {
		opts = append(opts, config...)
	}

	if serverConfig.UseTelemetry {
		meterProvider, err := initMeterProvider(context.Background())
		if err != nil {
			return nil, err
		}
		meterOpts := []kotel.MeterOpt{kotel.MeterProvider(meterProvider)}
		meter := kotel.NewMeter(meterOpts...)

		tracerProvider, err := initTracerProvider(context.Background())
		if err != nil {
			return nil, err
		}
		tracerOpts := []kotel.TracerOpt{
			kotel.TracerProvider(tracerProvider),
			kotel.TracerPropagator(propagation.NewCompositeTextMapPropagator(propagation.TraceContext{})),
		}
		tracer := kotel.NewTracer(tracerOpts...)

		kotelOps := []kotel.Opt{
			kotel.WithTracer(tracer),
			kotel.WithMeter(meter),
		}

		kotelService := kotel.NewKotel(kotelOps...)
		kotelOpt := kgo.WithHooks(kotelService.Hooks()...)
		opts = append(opts, kotelOpt)
	}

	if serverConfig.ScramAlgorithm != "" {
		var scramOpt kgo.Opt

		scramAuth := scram.Auth{
			User: serverConfig.UserName,
			Pass: serverConfig.Password,
		}

		switch serverConfig.ScramAlgorithm {
		case Scram256:
			scramOpt = kgo.SASL(scramAuth.AsSha256Mechanism())
		case Scram512:
			scramOpt = kgo.SASL(scramAuth.AsSha512Mechanism())
		}

		opts = append(opts, scramOpt)
	}

	if serverConfig.TLS {
		tlsOpt := kgo.DialTLS()
		opts = append(opts, tlsOpt)
	}

	client, err := kgo.NewClient(opts...)
	if err != nil {
		return nil, err
	}

	return client, nil
}

func initTracerProvider(ctx context.Context) (*trace.TracerProvider, error) {
	traceExporter, err := otlptracegrpc.New(ctx)
	if err != nil {
		return nil, err
	}

	tracerProvider := trace.NewTracerProvider(
		trace.WithBatcher(traceExporter),
	)

	return tracerProvider, nil
}

func initMeterProvider(ctx context.Context) (*metric.MeterProvider, error) {
	metricExporter, err := otlpmetricgrpc.New(ctx)
	if err != nil {
		return nil, err
	}

	meterProvider := metric.NewMeterProvider(
		metric.WithReader(metric.NewPeriodicReader(metricExporter,
			metric.WithInterval(60*time.Second))),
	)

	return meterProvider, nil
}
