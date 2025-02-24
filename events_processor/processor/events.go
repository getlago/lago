package processor

import (
	"context"
	"encoding/json"
	"log/slog"
	"os"
	"sync"

	"github.com/getlago/lago/events-processor/config/kafka"
	"github.com/getlago/lago/events-processor/models"
	"github.com/twmb/franz-go/pkg/kgo"
)

var (
	ctx                     context.Context
	logger                  *slog.Logger
	err                     error
	eventsEnrichedProducer  *kafka.Producer
	eventsInAdvanceProducer *kafka.Producer
	eventsDeadLetterQueue   *kafka.Producer
)

func processEvents(records []*kgo.Record) []*kgo.Record {
	wg := sync.WaitGroup{}
	mu := sync.Mutex{}
	wg.Add(len(records))

	for _, record := range records {
		go func(record *kgo.Record) {
			defer wg.Done()

			if ok := processEvent(record); ok == nil {
				// TODO: do we need the mutex here?
				mu.Lock()
				pushToDeadLetterQueue(record)
				mu.Unlock()
			}
		}(record)
	}

	wg.Wait()

	// TODO: only return a status / offset, to allow commit
	return records
}

func processEvent(record *kgo.Record) *kgo.Record {
	event := models.Event{}
	err := json.Unmarshal(record.Value, &event)
	if err != nil {
		logger.Error("Error unmarshalling message", slog.String("error", err.Error()))
		return nil
	}

	if event.Source != models.HTTP_RUBY {
		// TODO
	}

	// TODO

	return record
}

func pushToDeadLetterQueue(record *kgo.Record) {
	eventsDeadLetterQueue.Produce(ctx, &kafka.ProducerMessage{
		Value: record.Value,
	})
}

func StartProcessingEvents() {
	ctx = context.Background()

	logger = slog.New(slog.NewJSONHandler(os.Stdout, nil)).
		With("service", "post_process")
	slog.SetDefault(logger)

	if os.Getenv("KAFKA_EVENTS_ENRICHED_TOPIC") == "" {
		logger.Error("KAFKA_EVENTS_ENRICHED_TOPIC is required")
		os.Exit(1)
	}

	if os.Getenv("KAFKA_EVENTS_IN_ADVANCE_TOPIC") == "" {
		logger.Error("KAFKA_EVENTS_IN_ADVANCE_TOPIC is required")
		os.Exit(1)
	}

	eventsEnrichedProducer, err = kafka.NewProducer(&kafka.ProducerConfig{
		Topic: os.Getenv("KAFKA_EVENTS_ENRICHED_TOPIC"),
	})
	if err != nil {
		os.Exit(1)
	}
	err = eventsEnrichedProducer.Ping(ctx)
	if err != nil {
		os.Exit(1)
	}

	eventsInAdvanceProducer, err = kafka.NewProducer(&kafka.ProducerConfig{
		Topic: os.Getenv("KAFKA_EVENTS_IN_ADVANCE_TOPIC"),
	})
	if err != nil {
		os.Exit(1)
	}
	err = eventsInAdvanceProducer.Ping(ctx)
	if err != nil {
		os.Exit(1)
	}

	eventsDeadLetterQueue, err = kafka.NewProducer(&kafka.ProducerConfig{
		Topic: os.Getenv("KAFKA_EVENTS_DEAD_LETTER_QUEUE"),
	})
	if err != nil {
		os.Exit(1)
	}
	err = eventsDeadLetterQueue.Ping(ctx)
	if err != nil {
		os.Exit(1)
	}

	cg, err := kafka.NewConsumerGroup(&kafka.ConsumerGroupConfig{
		Topic:         os.Getenv("KAFKA_EVENTS_RAW_TOPIC"),
		ConsumerGroup: os.Getenv("KAFKA_CONSUMER_GROUP"),
		ProcessRecords: func(records []*kgo.Record) []*kgo.Record {
			return processEvents(records)
		},
	})
	if err != nil {
		os.Exit(1)
	}

	cg.Start()
}
