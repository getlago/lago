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
		func(ctx context.Context, event *models.Event) utils.AnyResult {
			return processor.processEvent(ctx, event)
		},
		processor.ProducerService.ProduceToDeadLetterQueue,
	)
}

// processEvent writes the enriched event. Pricing in advance is not handled yet:
// the API has no consumer for product events billed in advance.
func (processor *ProductProcessor) processEvent(ctx context.Context, event *models.Event) utils.Result[*models.ProductEnrichedEvent] {
	enrichedEventResult := processor.EnrichmentService.EnrichEvent(event)
	if enrichedEventResult.Failure() {
		return enrichedEventResult
	}

	processor.ProducerService.ProduceEnrichedEvent(ctx, enrichedEventResult.Value())

	return enrichedEventResult
}
