package kafka

import (
	"context"
	"log/slog"

	"github.com/twmb/franz-go/pkg/kgo"

	tracer "github.com/getlago/lago/events-processor/config"
	"github.com/getlago/lago/events-processor/utils"
)

type ProducerConfig struct {
	Topic string
}

type Producer struct {
	client *kgo.Client
	config ProducerConfig
	logger *slog.Logger
}

type ProducerMessage struct {
	Key   []byte
	Value []byte
}

type MessageProducer interface {
	Produce(context.Context, *ProducerMessage) bool
	GetTopic() string
}

func NewProducer(serverConfig ServerConfig, cfg *ProducerConfig) (*Producer, error) {
	opts := make([]kgo.Opt, 0)
	kcl, err := NewKafkaClient(serverConfig, opts)
	if err != nil {
		return nil, err
	}

	logger := slog.Default()
	logger = logger.With("component", "kafka-producer")

	pdr := &Producer{
		client: kcl,
		config: *cfg,
		logger: logger,
	}

	return pdr, nil
}

func (p *Producer) Produce(ctx context.Context, msg *ProducerMessage) bool {
	span := tracer.GetTracerSpan(ctx, "post_process", "Producer.Produce")
	defer span.End()

	record := &kgo.Record{
		Topic: p.config.Topic,
		Key:   msg.Key,
		Value: msg.Value,
	}

	pr := p.client.ProduceSync(ctx, record)
	if err := pr.FirstErr(); err != nil {
		p.logger.Error("record had a produce error while synchronously producing", slog.String("error", err.Error()))
		utils.CaptureError(err)
		return false
	}

	return true
}

func (p *Producer) Ping(ctx context.Context) error {
	return p.client.Ping(ctx)
}

func (p *Producer) GetTopic() string {
	return p.config.Topic
}
