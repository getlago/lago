package processors

import (
	"context"
	"encoding/json"
	"log/slog"
	"sync"
	"time"

	"github.com/twmb/franz-go/pkg/kgo"
	"go.opentelemetry.io/otel/attribute"

	tracer "github.com/getlago/lago/events-processor/config"
	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/utils"
)

func processEvents(records []*kgo.Record) []*kgo.Record {
	ctx := context.Background()
	span := tracer.GetTracerSpan(ctx, "post_process", "PostProcess.ProcessEvents")
	recordsAttr := attribute.Int("records.length", len(records))
	span.SetAttributes(recordsAttr)
	defer span.End()

	wg := sync.WaitGroup{}
	wg.Add(len(records))

	var mu sync.Mutex
	processedRecords := make([]*kgo.Record, 0)

	for _, record := range records {
		go func(record *kgo.Record) {
			defer wg.Done()

			sp := tracer.GetTracerSpan(ctx, "post_process", "PostProcess.ProcessOneEvent")
			defer sp.End()

			event := models.Event{}
			err := json.Unmarshal(record.Value, &event)
			if err != nil {
				logger.Error("Error unmarshalling message", slog.String("error", err.Error()))
				utils.CaptureError(err)

				mu.Lock()
				// If we fail to unmarshal the record, we should commit it as it will failed forever
				processedRecords = append(processedRecords, record)
				mu.Unlock()
				return
			}

			result := processEvent(&event)
			if result.Failure() {
				logger.Error(
					result.ErrorMessage(),
					slog.String("error_code", result.ErrorCode()),
					slog.String("error", result.ErrorMsg()),
				)

				if result.IsCapturable() {
					utils.CaptureErrorResultWithExtra(result, "event", event)
				}

				if result.IsRetryable() && time.Since(event.IngestedAt.Time()) < 12*time.Hour {
					// For retryable errors, we should avoid commiting the record,
					// It will be consumed again and reprocessed
					// Events older than 12 hours should also be pushed dead letter queue
					return
				}

				// Push failed records to the dead letter queue
				go processor.ProducerService.ProduceToDeadLetterQueue(ctx, event, result)
			}

			// Track processed records
			mu.Lock()
			processedRecords = append(processedRecords, record)
			mu.Unlock()
		}(record)
	}

	wg.Wait()

	return processedRecords
}

func processEvent(event *models.Event) utils.Result[*models.EnrichedEvent] {
	enrichedEventResult := processor.EnrichmentService.EnrichEvent(event)
	if enrichedEventResult.Failure() {
		return failedResult(enrichedEventResult, enrichedEventResult.ErrorCode(), enrichedEventResult.ErrorMessage())
	}

	enrichedEvents := enrichedEventResult.Value()
	enrichedEvent := enrichedEvents[0]

	go processor.ProducerService.ProduceEnrichedEvent(ctx, enrichedEvent)

	// TODO(pre-aggregation): Uncomment to enable the feature
	// for _, ev := range enrichedEvents {
	// 	go processor.ProducerService.ProduceEnrichedExpendedEvent(ctx, ev)
	// }

	if enrichedEvent.Subscription != nil && event.NotAPIPostProcessed() {
		payInAdvance := false
		for _, ev := range enrichedEvents {
			if ev.FlatFilter != nil && ev.FlatFilter.PayInAdvance {
				payInAdvance = true
				break
			}
		}

		if payInAdvance {
			go processor.ProducerService.ProduceChargedInAdvanceEvent(ctx, enrichedEvent)
		}

		flagResult := processor.RefreshService.FlagSubscriptionRefresh(enrichedEvent)
		if flagResult.Failure() {
			return failedResult(flagResult, "flag_subscription_refresh", "Error flagging subscription refresh")
		}

		// Expire cache at charge and charge filter level
		processor.CacheService.ExpireCache(enrichedEvents)
	}

	return utils.SuccessResult(enrichedEvent)
}

func failedResult(r utils.AnyResult, code string, message string) utils.Result[*models.EnrichedEvent] {
	result := utils.FailedResult[*models.EnrichedEvent](r.Error()).AddErrorDetails(code, message)
	result.Retryable = r.IsRetryable()
	result.Capture = r.IsCapturable()
	return result
}
