package processor

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"os"
	"sync"

	"github.com/getlago/lago-expression/expression-go"
	"github.com/getlago/lago/events-processor/config"
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
	db                      *config.DB
)

func processEvents(records []*kgo.Record) []*kgo.Record {
	wg := sync.WaitGroup{}
	mu := sync.Mutex{}
	wg.Add(len(records))

	for _, record := range records {
		go func(record *kgo.Record) {
			defer wg.Done()

			if ok := processEvent(record); ok == nil {
				// TODO: Do we need the mutex here?
				// 			 How to handle some auto retry?
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

	bm, err := db.FetchBillableMetric(event.OrganizationID, event.Code)
	if err != nil {
		logger.Error("Error fetching billable metric", slog.String("error", err.Error()))
		return nil
	}

	if event.Source != models.HTTP_RUBY {
		sub, err := db.FetchSubscription(event.OrganizationID, event.ExternalSubscriptionID, event.TimestampAsTime())
		if err != nil {
			return nil
		}

		if !enrichEventWithBM(&event, bm) {
			// TODO: log
			return nil
		}

		hasCharge, err := db.AnyInAdvanceCharge(sub.PlanID, bm.ID)
		if err != nil {
			// TODO: log
			return nil
		}

		if hasCharge {
			go produceInAdvanceEvent(&event)
		}
	}

	var value = fmt.Sprintf("%v", event.Properties[bm.FieldName])
	event.Value = &value
	go produceEvent(&event)

	return record
}

func pushToDeadLetterQueue(record *kgo.Record) {
	eventsDeadLetterQueue.Produce(ctx, &kafka.ProducerMessage{
		Value: record.Value,
	})
}

func enrichEventWithBM(ev *models.Event, bm *models.BillableMetric) bool {
	if bm.Expression != "" {
		eventJson, err := json.Marshal(ev)
		if err != nil {
			logger.Error("error while marshaling events")
			return false
		}
		eventJsonString := string(eventJson[:])

		result := expression.Evaluate(bm.Expression, eventJsonString)
		if result != nil {
			ev.Properties[bm.FieldName] = *result
		} else {
			logger.Error(fmt.Sprintf("Failed to evaluate expr: %s with json: %s", bm.Expression, eventJsonString))
			return false
		}
	}

	return true
}

func produceEvent(ev *models.Event) {
	eventJson, err := json.Marshal(ev)
	if err != nil {
		logger.Error("error while marshaling enriched events")
	}

	msgKey := fmt.Sprintf("%s-%s-%s", ev.OrganizationID, ev.ExternalSubscriptionID, ev.Code)

	// TODO: how to ensure message has been produced?
	eventsEnrichedProducer.Produce(ctx, &kafka.ProducerMessage{
		Key:   []byte(msgKey),
		Value: eventJson,
	})
}

func produceInAdvanceEvent(ev *models.Event) {
	eventJson, err := json.Marshal(ev)
	if err != nil {
		logger.Error("error while marshaling enriched events")
	}

	msgKey := fmt.Sprintf("%s-%s-%s", ev.OrganizationID, ev.ExternalSubscriptionID, ev.Code)

	// TODO: how to ensure message has been produced?
	eventsInAdvanceProducer.Produce(ctx, &kafka.ProducerMessage{
		Key:   []byte(msgKey),
		Value: eventJson,
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

	db, err = config.NewConnection()
	if err != nil {
		os.Exit(1)
	}

	cg.Start()
}
