package catalog_processor

import (
	"context"

	"github.com/twmb/franz-go/pkg/kgo"

	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/processors/pipeline"
	"github.com/getlago/lago/events-processor/utils"
)

// CatalogProcessor consumes the catalog raw topic, where product catalog
// organizations send their events keyed by external_contract_id.
type CatalogProcessor struct {
	EnrichmentService *EnrichmentService
	ProducerService   *ProducerService
}

func NewCatalogProcessor(enrichmentService *EnrichmentService, producerService *ProducerService) *CatalogProcessor {
	return &CatalogProcessor{
		EnrichmentService: enrichmentService,
		ProducerService:   producerService,
	}
}

func (processor *CatalogProcessor) ProcessEvents(ctx context.Context, records []*kgo.Record) []*kgo.Record {
	return pipeline.ProcessRecords(
		ctx,
		records,
		"CatalogProcess.ProcessEvents",
		func(ctx context.Context, event *models.Event) utils.AnyResult {
			return processor.processEvent(ctx, event)
		},
		processor.ProducerService.ProduceToDeadLetterQueue,
	)
}

// processEvent writes the enriched event and, when the contract bills the metric
// in advance, sends it to the API to price the fee.
func (processor *CatalogProcessor) processEvent(ctx context.Context, event *models.Event) utils.Result[*models.CatalogEnrichedEvent] {
	enrichedEventResult := processor.EnrichmentService.EnrichEvent(event)
	if enrichedEventResult.Failure() {
		return enrichedEventResult
	}

	enrichedEvent := enrichedEventResult.Value()
	processor.ProducerService.ProduceEnrichedEvent(ctx, enrichedEvent)

	if event.NotAPIPostProcessed() {
		advanceResult := processor.EnrichmentService.HasAdvanceRateCard(enrichedEvent)
		if advanceResult.Failure() {
			return pipeline.FailedResult[*models.CatalogEnrichedEvent](advanceResult, "fetch_advance_rate_card", "Error fetching advance rate card")
		}

		if advanceResult.Value() {
			processor.ProducerService.ProduceChargedInAdvanceEvent(ctx, enrichedEvent.ToChargedInAdvanceEvent())
		}
	}

	return enrichedEventResult
}
