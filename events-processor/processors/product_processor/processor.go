package product_processor

import (
	"context"

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
}

func NewProductProcessor(enrichmentService *EnrichmentService, producerService *ProducerService) *ProductProcessor {
	return &ProductProcessor{
		EnrichmentService: enrichmentService,
		ProducerService:   producerService,
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
func (processor *ProductProcessor) processEvent(ctx context.Context, event *models.ProductEvent) utils.Result[*models.ProductEnrichedEvent] {
	enrichedEventResult := processor.EnrichmentService.EnrichEvent(event)
	if enrichedEventResult.Failure() {
		return enrichedEventResult
	}

	enrichedEvent := enrichedEventResult.Value()
	processor.ProducerService.ProduceEnrichedEvent(ctx, enrichedEvent)

	if processor.ProducerService.ChargesInAdvance() && event.NotAPIPostProcessed() {
		advanceResult := processor.EnrichmentService.HasAdvanceRateCard(enrichedEvent)
		if advanceResult.Failure() {
			return pipeline.FailedResult[*models.ProductEnrichedEvent](advanceResult, "fetch_advance_rate_card", "Error fetching advance rate card")
		}

		if advanceResult.Value() {
			processor.ProducerService.ProduceChargedInAdvanceEvent(ctx, enrichedEvent)
		}
	}

	return enrichedEventResult
}
