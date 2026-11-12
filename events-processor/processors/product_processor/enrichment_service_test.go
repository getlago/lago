package product_processor

import (
	"testing"

	"github.com/stretchr/testify/assert"

	"github.com/getlago/lago/events-processor/models"
)

func TestEnrichEvent(t *testing.T) {
	for _, mode := range testModes {
		t.Run(mode.name, func(t *testing.T) {
			t.Run("enriches the event from its billable metric", func(t *testing.T) {
				env := setupTestEnv(t, mode.useCache)
				defer env.Cleanup()

				event := buildEvent()
				env.DataStore.SetBillableMetric(buildBillableMetric())

				result := env.Processor.EnrichmentService.EnrichEvent(&event)

				assert.True(t, result.Success())
				enriched := result.Value()
				assert.Equal(t, "bm123", enriched.BillableMetric.ID)
				assert.Equal(t, "contract_ext_id", enriched.ExternalContractID)
				assert.Equal(t, "tx_1", enriched.TransactionID)
				assert.Equal(t, "sum", enriched.AggregationType)
				assert.Equal(t, "12.0", *enriched.Value)
				assert.Equal(t, 1741007009.0, enriched.Timestamp)
			})

			t.Run("fails without a billable metric", func(t *testing.T) {
				env := setupTestEnv(t, mode.useCache)
				defer env.Cleanup()

				event := buildEvent()
				env.DataStore.ExpectBillableMetricNotFound()

				result := env.Processor.EnrichmentService.EnrichEvent(&event)

				assert.False(t, result.Success())
				assert.Equal(t, "fetch_billable_metric", result.ErrorCode())
			})
		})
	}

	t.Run("rejects an event without external_contract_id", func(t *testing.T) {
		env := setupTestEnv(t, true)
		defer env.Cleanup()

		event := buildEvent()
		event.ExternalContractID = ""

		result := env.Processor.EnrichmentService.EnrichEvent(&event)

		assert.False(t, result.Success())
		assert.Equal(t, "missing_external_contract_id", result.ErrorCode())
		assert.False(t, result.IsRetryable())
		assert.False(t, result.IsCapturable())
	})
}

func TestHasAdvanceRateCard(t *testing.T) {
	for _, mode := range testModes {
		t.Run(mode.name, func(t *testing.T) {
			t.Run("looks the contract's rate cards up for the event's billable metric", func(t *testing.T) {
				env := setupTestEnvChargingInAdvance(t, mode.useCache)
				defer env.Cleanup()

				env.DataStore.ExpectAdvanceRateCard(true)

				event := buildEvent()
				enriched := &models.ProductEnrichedEvent{
					OrganizationID:     orgID,
					ExternalContractID: event.ExternalContractID,
					BillableMetric:     buildBillableMetric(),
				}
				result := env.Processor.EnrichmentService.HasAdvanceRateCard(enriched)

				assert.True(t, result.Success())
				assert.True(t, result.Value())
			})

			// Enrichment succeeds without a billable metric when the store returns none:
			// the lookup must not run, nor read the missing metric's id.
			t.Run("charges nothing in advance without a billable metric", func(t *testing.T) {
				env := setupTestEnvChargingInAdvance(t, mode.useCache)
				defer env.Cleanup()

				enriched := &models.ProductEnrichedEvent{OrganizationID: orgID, ExternalContractID: "contract_ext_id"}
				result := env.Processor.EnrichmentService.HasAdvanceRateCard(enriched)

				assert.True(t, result.Success())
				assert.False(t, result.Value())
			})
		})
	}
}
