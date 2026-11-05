package events_processor

import (
	"context"

	"github.com/twmb/franz-go/pkg/kgo"
	"golang.org/x/sync/errgroup"

	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/processors/pipeline"
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
	return pipeline.ProcessRecords(
		ctx,
		records,
		"PostProcess.ProcessEvents",
		func(ctx context.Context, event *models.Event) utils.AnyResult {
			return processor.processEvent(ctx, event)
		},
		processor.ProducerService.ProduceToDeadLetterQueue,
	)
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

func failedResult(r utils.AnyResult, code string, message string) utils.Result[*models.EnrichedEvent] {
	return pipeline.FailedResult[*models.EnrichedEvent](r, code, message)
}
