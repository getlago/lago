package events_processor

import (
	"context"
	"encoding/json"
	"log/slog"
	"sync"
	"time"

	"github.com/twmb/franz-go/pkg/kgo"
	"golang.org/x/sync/errgroup"

	"github.com/getlago/lago/events-processor/config/tracing"
	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/utils"
)

type EventProcessor struct {
	EnrichmentService *EventEnrichmentService
	ProducerService   *EventProducerService
	RefreshService    *SubscriptionRefreshService
}

func NewEventProcessor(enrichmentService *EventEnrichmentService, producerService *EventProducerService, refreshService *SubscriptionRefreshService) *EventProcessor {
	return &EventProcessor{
		EnrichmentService: enrichmentService,
		ProducerService:   producerService,
		RefreshService:    refreshService,
	}
}

func (processor *EventProcessor) ProcessEvents(ctx context.Context, records []*kgo.Record) []*kgo.Record {
	return processor.processRecords(ctx, records, "PostProcess.ProcessEvents", func(ctx context.Context, event *models.Event) utils.AnyResult {
		return processor.processEvent(ctx, event)
	})
}

// ProcessCatalogEvents consumes the catalog raw topic, where product catalog
// organizations send their events keyed by external_contract_id.
func (processor *EventProcessor) ProcessCatalogEvents(ctx context.Context, records []*kgo.Record) []*kgo.Record {
	return processor.processRecords(ctx, records, "PostProcess.ProcessCatalogEvents", func(ctx context.Context, event *models.Event) utils.AnyResult {
		return processor.processCatalogEvent(ctx, event)
	})
}

func (processor *EventProcessor) processRecords(ctx context.Context, records []*kgo.Record, spanName string, process func(context.Context, *models.Event) utils.AnyResult) []*kgo.Record {
	span := tracing.StartSpan(ctx, spanName)
	defer span.End()

	span.SetAttribute("records.length", len(records))

	g := errgroup.Group{}

	var mu sync.Mutex
	processedRecords := make([]*kgo.Record, 0)

	for _, record := range records {
		g.Go(func() error {
			func(record *kgo.Record) {
				sp := tracing.StartSpan(ctx, "PostProcess.ProcessOneEvent")
				defer sp.End()

				event := models.Event{}
				err := json.Unmarshal(record.Value, &event)
				if err != nil {
					slog.Error("Error unmarshalling message", slog.String("error", err.Error()))
					utils.CaptureError(err)

					mu.Lock()
					// If we fail to unmarshal the record, we should commit it as it will failed forever
					processedRecords = append(processedRecords, record)
					mu.Unlock()
					return
				}

				result := process(ctx, &event)
				if result.Failure() {
					slog.Error(
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
					processor.ProducerService.ProduceToDeadLetterQueue(ctx, event, result)
				}

				// Track processed records
				mu.Lock()
				processedRecords = append(processedRecords, record)
				mu.Unlock()
			}(record)

			return nil
		})
	}

	g.Wait()
	return processedRecords
}

func (processor *EventProcessor) processEvent(ctx context.Context, event *models.Event) utils.Result[*models.EnrichedEvent] {
	errgroup := errgroup.Group{}
	defer errgroup.Wait()

	enrichedEventResult := processor.EnrichmentService.EnrichEvent(event)
	if enrichedEventResult.Failure() {
		return failedResult(enrichedEventResult, enrichedEventResult.ErrorCode(), enrichedEventResult.ErrorMessage())
	}

	enrichedEvent := enrichedEventResult.Value()

	errgroup.Go(func() error {
		processor.ProducerService.ProduceEnrichedEvent(ctx, enrichedEvent)
		return nil
	})

	if enrichedEvent.Subscription != nil && event.NotAPIPostProcessed() {
		payInAdvanceResult := processor.EnrichmentService.HasPayInAdvanceCharge(enrichedEvent)
		if payInAdvanceResult.Failure() {
			return failedResult(payInAdvanceResult, "fetch_pay_in_advance_charge", "Error fetching pay in advance charge")
		}

		if payInAdvanceResult.Value() {
			errgroup.Go(func() error {
				processor.ProducerService.ProduceChargedInAdvanceEvent(ctx, enrichedEvent)
				return nil
			})
		}

		flagResult := processor.RefreshService.FlagSubscriptionRefresh(ctx, enrichedEvent)
		if flagResult.Failure() {
			return failedResult(flagResult, "flag_subscription_refresh", "Error flagging subscription refresh")
		}
	}

	return utils.SuccessResult(enrichedEvent)
}

// processCatalogEvent writes the enriched event and, when the contract bills the
// metric in advance, sends it to the API to price the fee. Refresh flags for
// contracts come with the API side that consumes them.
func (processor *EventProcessor) processCatalogEvent(ctx context.Context, event *models.Event) utils.Result[*models.CatalogEnrichedEvent] {
	enrichedEventResult := processor.EnrichmentService.EnrichCatalogEvent(event)
	if enrichedEventResult.Failure() {
		return enrichedEventResult
	}

	enrichedEvent := enrichedEventResult.Value()
	processor.ProducerService.ProduceCatalogEnrichedEvent(ctx, enrichedEvent)

	if event.NotAPIPostProcessed() {
		advanceResult := processor.EnrichmentService.HasAdvanceRateCard(enrichedEvent)
		if advanceResult.Failure() {
			return failedResultFor[*models.CatalogEnrichedEvent](advanceResult, "fetch_advance_rate_card", "Error fetching advance rate card")
		}

		if advanceResult.Value() {
			processor.ProducerService.ProduceChargedInAdvanceEvent(ctx, enrichedEvent.ToChargedInAdvanceEvent())
		}
	}

	return enrichedEventResult
}

func failedResult(r utils.AnyResult, code string, message string) utils.Result[*models.EnrichedEvent] {
	return failedResultFor[*models.EnrichedEvent](r, code, message)
}

func failedResultFor[T any](r utils.AnyResult, code string, message string) utils.Result[T] {
	result := utils.FailedResult[T](r.Error()).AddErrorDetails(code, message)
	result.Retryable = r.IsRetryable()
	result.Capture = r.IsCapturable()
	return result
}
