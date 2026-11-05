package pipeline

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"time"

	"github.com/getlago/lago/events-processor/config/kafka"
	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/utils"
)

// Producer pushes messages to a topic and sends the events it fails to push
// to the dead letter queue. E is the raw event of the pipeline.
type Producer[E any] struct {
	deadLetterProducer kafka.MessageProducer
}

func NewProducer[E any](deadLetterProducer kafka.MessageProducer) Producer[E] {
	return Producer[E]{deadLetterProducer: deadLetterProducer}
}

func (p Producer[E]) Produce(context context.Context, event any, initialEvent *E, msgKey string, producer kafka.MessageProducer) error {
	eventJson, err := json.Marshal(event)
	if err != nil {
		return err
	}

	pushed := producer.Produce(context, &kafka.ProducerMessage{
		Key:   []byte(msgKey),
		Value: eventJson,
	})

	if !pushed {
		p.ProduceToDeadLetterQueue(context, *initialEvent, utils.FailedBoolResult(fmt.Errorf("failed to push to %s topic", producer.GetTopic())))
	}

	return nil
}

func (p Producer[E]) ProduceToDeadLetterQueue(context context.Context, event E, errorResult utils.AnyResult) {
	failedEvent := models.DeadLetterEvent[E]{
		Event:               event,
		InitialErrorMessage: errorResult.ErrorMsg(),
		ErrorCode:           errorResult.ErrorCode(),
		ErrorMessage:        errorResult.ErrorMessage(),
		FailedAt:            time.Now(),
	}

	eventJson, err := json.Marshal(failedEvent)
	if err != nil {
		slog.Error("error while marshaling failed event with error details")
		utils.CaptureError(err)
	}

	pushed := p.deadLetterProducer.Produce(context, &kafka.ProducerMessage{
		Value: eventJson,
	})

	if !pushed {
		slog.Error("error while pushing to dead letter topic", slog.String("topic", p.deadLetterProducer.GetTopic()))
		utils.CaptureErrorResultWithExtra(errorResult, "event", event)
	}
}
