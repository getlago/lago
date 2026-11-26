package product_processor

import (
	"context"
	"log/slog"

	"github.com/twmb/franz-go/pkg/kgo"

	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/processors/pipeline"
	"github.com/getlago/lago/events-processor/utils"
)

// ProductProcessor consumes the product raw events topic, where product catalog
// organizations send their events keyed by external_contract_id.
type ProductProcessor struct {
	EnrichmentService *EnrichmentService
	ProducerService   *ProducerService
	RefreshService    *ContractRefreshService
}

func NewProductProcessor(enrichmentService *EnrichmentService, producerService *ProducerService, refreshService *ContractRefreshService) *ProductProcessor {
	return &ProductProcessor{
		EnrichmentService: enrichmentService,
		ProducerService:   producerService,
		RefreshService:    refreshService,
	}
}

func (processor *ProductProcessor) ProcessEvents(ctx context.Context, records []*kgo.Record) []*kgo.Record {
	return pipeline.ProcessRecords(
		ctx,
		records,
		"ProductProcess.ProcessEvents",
		func(ctx context.Context, event *models.ProductEvent) utils.AnyResult {
			return processor.processEvent(ctx, event)
		},
		processor.ProducerService.ProduceToDeadLetterQueue,
	)
}

// processEvent writes the enriched event, and also sends it to the in advance topic
// when its contract bills the metric in advance. The API then picks the rate card.
// It then flags the contract, so that the API evaluates its alerts.
func (processor *ProductProcessor) processEvent(ctx context.Context, event *models.ProductEvent) utils.Result[*models.ProductEnrichedEvent] {
	enrichedEventResult := processor.EnrichmentService.EnrichEvent(event)
	if enrichedEventResult.Failure() {
		return enrichedEventResult
	}

	enrichedEvent := enrichedEventResult.Value()

	// Looked up before anything is produced: a failure is retried, and the retry
	// must not write the enriched event a second time.
	chargedInAdvance := false
	if processor.ProducerService.ChargesInAdvance() && event.NotAPIPostProcessed() {
		advanceResult := processor.EnrichmentService.HasAdvanceRateCard(enrichedEvent)
		if advanceResult.Failure() {
			return pipeline.FailedResult[*models.ProductEnrichedEvent](advanceResult, "fetch_advance_rate_card", "Error fetching advance rate card")
		}
		chargedInAdvance = advanceResult.Value()
	}

	processor.ProducerService.ProduceEnrichedEvent(ctx, enrichedEvent)
	if chargedInAdvance {
		processor.ProducerService.ProduceChargedInAdvanceEvent(ctx, enrichedEvent)
	}

	// The API tracks the contract of the events it post processes itself. A failed
	// flag does not fail the event, which is already written: failing it would send
	// the event to the dead letter queue or write it twice. The next event of the
	// contract flags it again.
	if event.NotAPIPostProcessed() {
		flagResult := processor.RefreshService.FlagContractRefresh(ctx, enrichedEvent)
		if flagResult.Failure() {
			slog.Error(
				"Error flagging contract refresh",
				slog.String("organization_id", enrichedEvent.OrganizationID),
				slog.String("external_contract_id", enrichedEvent.ExternalContractID),
				slog.String("error", flagResult.ErrorMsg()),
			)
			utils.CaptureError(flagResult.Error())
		}
	}

	return enrichedEventResult
}
