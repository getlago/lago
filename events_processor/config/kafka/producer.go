package kafka

import (
	"context"
	"log/slog"

	"github.com/twmb/franz-go/pkg/kgo"
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

func NewProducer(cfg *ProducerConfig) (*Producer, error) {
	opts := make([]kgo.Opt, 0)
	kcl, err := NewKafkaClient(opts)
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
	record := &kgo.Record{
		Topic: p.config.Topic,
		Key:   msg.Key,
		Value: msg.Value,
	}

	pr := p.client.ProduceSync(ctx, record)
	if err := pr.FirstErr(); err != nil {
		p.logger.Error("record had a produce error while synchronously producing", slog.String("error", err.Error()))
		// TODO: should return error?
		return false
	}

	return true
}

func (p *Producer) Ping(ctx context.Context) error {
	return p.client.Ping(ctx)
}
