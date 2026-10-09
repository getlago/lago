package product_processor

import (
	"errors"

	"github.com/getlago/lago/events-processor/cache"
	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/processors/pipeline"
	"github.com/getlago/lago/events-processor/utils"
)

type EnrichmentService struct {
	apiStore *models.ApiStore
	memCache *cache.Cache
}

func NewEnrichmentService(apiStore *models.ApiStore, memCache *cache.Cache) *EnrichmentService {
	return &EnrichmentService{
		apiStore: apiStore,
		memCache: memCache,
	}
}

// EnrichEvent enriches the event from its billable metric. The contract and its
// rate cards are not resolved here: the API matches them when it reads.
func (s *EnrichmentService) EnrichEvent(event *models.Event) utils.Result[*models.ProductEnrichedEvent] {
	// Without it the event can't be tied to a contract nor aggregated: a payload
	// sent to the product topic by mistake goes to the dead letter queue.
	if event.ExternalContractID == "" {
		missing := utils.FailedResult[*models.ProductEnrichedEvent](errors.New("external_contract_id is missing")).
			NonRetryable().NonCapturable()
		return pipeline.FailedResult[*models.ProductEnrichedEvent](missing, "missing_external_contract_id", "Product event without external_contract_id")
	}

	enrichedEventResult := pipeline.NewBillableMetricEnricher(s.apiStore, s.memCache).Enrich(event)
	if enrichedEventResult.Failure() {
		return pipeline.FailedResult[*models.ProductEnrichedEvent](enrichedEventResult, enrichedEventResult.ErrorCode(), enrichedEventResult.ErrorMessage())
	}

	return utils.SuccessResult(enrichedEventResult.Value().ToProductEnrichedEvent())
}
