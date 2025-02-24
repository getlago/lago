package kafka

import (
	"context"
	"fmt"
	"log/slog"
	"sync"

	"github.com/twmb/franz-go/pkg/kgo"
)

type ConsumerGroupConfig struct {
	Topic          string
	ConsumerGroup  string
	ProcessRecords func([]*kgo.Record) []*kgo.Record
}

type TopicPartition struct {
	topic     string
	partition int32
}

type PartitionConsumer struct {
	client    *kgo.Client
	logger    *slog.Logger
	topic     string
	partition int32

	quit           chan struct{}
	done           chan struct{}
	records        chan []*kgo.Record
	processRecords func([]*kgo.Record) []*kgo.Record
}

type ConsumerGroup struct {
	consumers      map[TopicPartition]*PartitionConsumer
	client         *kgo.Client
	processRecords func([]*kgo.Record) []*kgo.Record
	logger         *slog.Logger
}

func (pc *PartitionConsumer) consume() {
	defer close(pc.done)

	pc.logger.Info(fmt.Sprintf("Starting consume for topic %s partition %d\n", pc.topic, pc.partition))
	defer pc.logger.Info(fmt.Sprintf("Closing consume for topic %s partition %d\n", pc.topic, pc.partition))

	for {
		select {
		case <-pc.quit:
			pc.logger.Info("partition consmer quit")
			return

		case records := <-pc.records:
			processedRecords := pc.processRecords(records)

			// TODO: See https://pkg.go.dev/github.com/twmb/franz-go@v1.18.1/pkg/kgo#Client.CommitRecords
			// CommitRecords should not be used in this context
			err := pc.client.CommitRecords(context.Background(), processedRecords...)
			if err != nil {
				pc.logger.Error(fmt.Sprintf("Error when committing offets to kafka. Error: %v topic: %s partition: %d offset: %d\n", err, pc.topic, pc.partition, records[len(records)-1].Offset+1))
			}
		}
	}
}

func (cg *ConsumerGroup) assigned(_ context.Context, cl *kgo.Client, assigned map[string][]int32) {
	for topic, partitions := range assigned {
		for _, partition := range partitions {
			pc := &PartitionConsumer{
				client:    cl,
				topic:     topic,
				partition: partition,
				logger:    cg.logger,

				quit:           make(chan struct{}),
				done:           make(chan struct{}),
				records:        make(chan []*kgo.Record),
				processRecords: cg.processRecords,
			}
			cg.consumers[TopicPartition{topic: topic, partition: partition}] = pc
			go pc.consume()
		}
	}
}

func (cg *ConsumerGroup) lost(_ context.Context, _ *kgo.Client, lost map[string][]int32) {
	var wg sync.WaitGroup
	defer wg.Wait()

	for topic, partitions := range lost {
		for _, partition := range partitions {
			tp := TopicPartition{topic: topic, partition: partition}
			pc := cg.consumers[tp]
			delete(cg.consumers, tp)
			close(pc.quit)

			pc.logger.Info(fmt.Sprintf("waiting for work to finish topic %s partition %d\n", topic, partition))
			wg.Add(1)
			go func() { <-pc.done; wg.Done() }()
		}
	}
}

func (cg *ConsumerGroup) poll() {
	for {
		fetches := cg.client.PollRecords(context.Background(), 10000)
		if fetches.IsClientClosed() {
			cg.logger.Info("client closed")
			return
		}

		fetches.EachError(func(_ string, _ int32, err error) {
			panic(err)
		})

		fetches.EachPartition(func(p kgo.FetchTopicPartition) {
			tp := TopicPartition{p.Topic, p.Partition}
			cg.consumers[tp].records <- p.Records
		})

		cg.client.AllowRebalance()
	}
}

func NewConsumerGroup(cfg *ConsumerGroupConfig) (*ConsumerGroup, error) {
	logger := slog.Default()
	logger = logger.With("kafka-topic-consumer", cfg.Topic)

	cg := &ConsumerGroup{
		consumers:      make(map[TopicPartition]*PartitionConsumer),
		processRecords: cfg.ProcessRecords,
		logger:         logger,
	}

	cgName := fmt.Sprintf("%s_%s", cfg.ConsumerGroup, cfg.Topic)
	opts := []kgo.Opt{
		kgo.ConsumerGroup(cgName),
		kgo.ConsumeTopics(cfg.Topic),
		kgo.OnPartitionsAssigned(cg.assigned),
		kgo.OnPartitionsLost(cg.lost),
		kgo.OnPartitionsRevoked(cg.lost),
		kgo.DisableAutoCommit(),
		kgo.BlockRebalanceOnPoll(),
	}

	kcl, err := NewKafkaClient(opts)
	if err != nil {
		return nil, err
	}

	if err = kcl.Ping(context.Background()); err != nil {
		return nil, err
	}

	cg.client = kcl
	return cg, nil
}

func (cg *ConsumerGroup) Start() {
	cg.poll()
}
