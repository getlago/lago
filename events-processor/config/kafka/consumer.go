package kafka

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"math"
	"sync"

	"github.com/twmb/franz-go/pkg/kgo"
	"go.opentelemetry.io/otel/attribute"

	tracer "github.com/getlago/lago/events-processor/config"
	"github.com/getlago/lago/events-processor/utils"
)

type ConsumerGroupConfig struct {
	Topic          string
	ConsumerGroup  string
	ProcessRecords func(context.Context, []*kgo.Record) []*kgo.Record
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
	processRecords func(context.Context, []*kgo.Record) []*kgo.Record
}

type ConsumerGroup struct {
	consumers      map[TopicPartition]*PartitionConsumer
	client         *kgo.Client
	processRecords func(context.Context, []*kgo.Record) []*kgo.Record
	logger         *slog.Logger
}

func (pc *PartitionConsumer) consume(ctx context.Context) {
	defer close(pc.done)

	pc.logger.Info(fmt.Sprintf("Starting consume for topic %s partition %d\n", pc.topic, pc.partition))
	defer pc.logger.Info(fmt.Sprintf("Closing consume for topic %s partition %d\n", pc.topic, pc.partition))

	for {
		select {
		case <-pc.quit:
			pc.logger.Info("partition consumer quit")
			return

		case <-ctx.Done():
			pc.logger.Info("partition consumer context canceled")
			return

		case records := <-pc.records:
			pc.processRecordsAndCommit(records)
		}
	}
}

func (pc *PartitionConsumer) processRecordsAndCommit(records []*kgo.Record) {
	ctx := context.Background()
	span := tracer.GetTracerSpan(ctx, "post_process", "Consumer.Consume")
	recordsAttr := attribute.Int("records.length", len(records))
	span.SetAttributes(recordsAttr)
	defer span.End()

	processedRecords := pc.processRecords(records)
	commitableRecords := records

	if len(processedRecords) != len(records) {
		// Ensure we are not committing records that were not processed and can be re-consumed
		record := findMaxCommitableRecord(processedRecords, records)
		commitableRecords = []*kgo.Record{record}
		return
	}

	err := pc.client.CommitRecords(ctx, commitableRecords...)
	if err != nil {
		pc.logger.Error(fmt.Sprintf("Error when committing offets to kafka. Error: %v topic: %s partition: %d offset: %d\n", err, pc.topic, pc.partition, records[len(records)-1].Offset+1))
		utils.CaptureError(err)
	}
}

func (cg *ConsumerGroup) assigned(ctx context.Context, cl *kgo.Client, assigned map[string][]int32) {
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
			go pc.consume(ctx)
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

func (cg *ConsumerGroup) poll(ctx context.Context, done chan<- error) {
	defer func() {
		if r := recover(); r != nil {
			cg.logger.Error("Consumer group poll panic", slog.Any("panic", r))
			done <- fmt.Errorf("consumer group poll panic: %v", r)
		}
	}()

	for {
		select {
		case <-ctx.Done():
			cg.logger.Info("Consumer group stopped")
			return

		default:
			if ok := cg.pollRecords(ctx); !ok {
				return
			}
		}
	}
}

func (cg *ConsumerGroup) pollRecords(ctx context.Context) bool {
	fetches := cg.client.PollRecords(ctx, 10000)
	if fetches.IsClientClosed() {
		cg.logger.Info("client closed")
		return false
	}

	hasContextError := false
	fetches.EachError(func(_ string, _ int32, err error) {
		if errors.Is(err, context.Canceled) || errors.Is(err, context.DeadlineExceeded) {
			hasContextError = true
			return
		}

		cg.logger.Error("Fetch error", slog.String("error", err.Error()))
		panic(err)
	})

	if hasContextError || ctx.Err() != nil {
		// Context was canceled before fetching records of while checking for errors
		return false
	}

	fetches.EachPartition(func(p kgo.FetchTopicPartition) {
		tp := TopicPartition{p.Topic, p.Partition}
		if consumer, exists := cg.consumers[tp]; exists {
			// Only send records if the consumer channel is still open
			select {
			case consumer.records <- p.Records:
			case <-ctx.Done():
				cg.logger.Info("Context canceled while sending records to partition consumer")
				return
			}
		}
	})

	cg.client.AllowRebalance()
	return true
}

func (cg *ConsumerGroup) gracefulShutdown() {
	var wg sync.WaitGroup

	for tp, pc := range cg.consumers {
		wg.Add(1)

		go func(tp TopicPartition, pc *PartitionConsumer) {
			defer wg.Done()

			cg.logger.Info("Shuting down partion consumer",
				slog.String("topic", tp.topic),
				slog.Int("partition", int(tp.partition)),
			)

			close(pc.quit)
			<-pc.done
		}(tp, pc)
	}

	wg.Wait()
	cg.client.Close()
}

func NewConsumerGroup(serverConfig ServerConfig, cfg *ConsumerGroupConfig) (*ConsumerGroup, error) {
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

	kcl, err := NewKafkaClient(serverConfig, opts)
	if err != nil {
		return nil, err
	}

	if err = kcl.Ping(context.Background()); err != nil {
		return nil, err
	}

	cg.client = kcl
	return cg, nil
}

func (cg *ConsumerGroup) Start(ctx context.Context) error {
	pollCtx, cancel := context.WithCancel(ctx)
	defer cancel()

	done := make(chan error, 1)
	go func() {
		defer close(done)
		cg.poll(pollCtx, done)
	}()

	select {
	case <-ctx.Done():
		cg.logger.Info("Gracefully shutting down consumer group")
		cancel()

		cg.gracefulShutdown()

		cg.logger.Info("Consumer group shutdown is complete")
		return ctx.Err()

	case err := <-done:
		if err != nil {
			cg.logger.Error("Consumer group stopped with error", slog.String("error", err.Error()))
		}
		return err
	}
}

func findMaxCommitableRecord(processedRecords []*kgo.Record, records []*kgo.Record) *kgo.Record {
	// Keep track of processed records
	processedMap := make(map[string]bool)
	for _, record := range processedRecords {
		key := fmt.Sprintf("%s-%d", string(record.Key), record.Offset)
		processedMap[key] = true
	}

	// Find the minimum offset of the unprocessed records
	minUnprocessedOffset := int64(math.MaxInt64)
	foundUnprocessed := false
	for _, record := range records {
		key := fmt.Sprintf("%s-%d", string(record.Key), record.Offset)
		if !processedMap[key] {
			if !foundUnprocessed || record.Offset < minUnprocessedOffset {
				minUnprocessedOffset = record.Offset
				foundUnprocessed = true
			}
		}
	}

	// Find the record with the offset just before the minimum unprocessed offset
	var maxRecord *kgo.Record
	for _, record := range processedRecords {
		if record.Offset < minUnprocessedOffset && (maxRecord == nil || record.Offset > maxRecord.Offset) {
			maxRecord = record
		}
	}

	return maxRecord
}
