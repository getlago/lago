package catalog_processor

import (
	"errors"
	"time"

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

// EnrichEvent enriches the event from its billable metric and resolves the
// contract serving it.
func (s *EnrichmentService) EnrichEvent(event *models.Event) utils.Result[*models.CatalogEnrichedEvent] {
	// Without it the event can't be tied to a contract nor aggregated: a payload
	// sent to the catalog topic by mistake goes to the dead letter queue.
	if event.ExternalContractID == "" {
		missing := utils.FailedResult[*models.CatalogEnrichedEvent](errors.New("external_contract_id is missing")).
			NonRetryable().NonCapturable()
		return pipeline.FailedResult[*models.CatalogEnrichedEvent](missing, "missing_external_contract_id", "Catalog event without external_contract_id")
	}

	enrichedEventResult := pipeline.NewBillableMetricEnricher(s.apiStore, s.memCache).Enrich(event)
	if enrichedEventResult.Failure() {
		return pipeline.FailedResult[*models.CatalogEnrichedEvent](enrichedEventResult, enrichedEventResult.ErrorCode(), enrichedEventResult.ErrorMessage())
	}

	enrichedEvent := enrichedEventResult.Value()
	bm := enrichedEvent.BillableMetric

	contractResult := s.fetchContract(event, enrichedEvent.Time)

	// For recurring billable metrics, if no contract serves the event timestamp,
	// fall back on the current contract rather than failing.
	if contractResult.Failure() && !contractResult.IsCapturable() && bm != nil && bm.Recurring {
		contractResult = s.fetchContract(event, time.Now())
	}

	if contractResult.Failure() {
		if contractResult.IsCapturable() {
			return pipeline.FailedResult[*models.CatalogEnrichedEvent](contractResult, "fetch_contract", "Error fetching contract")
		}

		contractResult = utils.SuccessResult[*models.Contract](nil)
	}

	return utils.SuccessResult(enrichedEvent.ToCatalogEnrichedEvent(contractResult.Value()))
}

// HasAdvanceRateCard reports whether the contract serving the event has a rate
// card billing its billable metric in advance.
func (s *EnrichmentService) HasAdvanceRateCard(event *models.CatalogEnrichedEvent) utils.Result[bool] {
	if event.Contract == nil || event.BillableMetric == nil {
		return utils.SuccessResult(false)
	}

	if s.memCache != nil {
		return s.memCache.HasAdvanceRateCard(event.OrganizationID, event.Contract.ID, event.BillableMetric.ID)
	}

	return s.apiStore.HasAdvanceRateCard(event.OrganizationID, event.Contract.ID, event.BillableMetric.ID)
}

func (s *EnrichmentService) fetchContract(event *models.Event, timestamp time.Time) utils.Result[*models.Contract] {
	if s.memCache != nil {
		return s.memCache.SearchContracts(event.OrganizationID, event.ExternalContractID, timestamp)
	}
	return s.apiStore.FetchContract(event.OrganizationID, event.ExternalContractID, timestamp)
}
