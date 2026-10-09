package catalog_processor

import (
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestEnrichEvent(t *testing.T) {
	for _, mode := range testModes {
		t.Run(mode.name, func(t *testing.T) {
			t.Run("enriches the event and resolves the contract serving it", func(t *testing.T) {
				env := setupTestEnv(t, mode.useCache)
				defer env.Cleanup()

				event := buildEvent()
				env.DataStore.SetBillableMetric(buildBillableMetric())
				env.DataStore.SetContract(buildContract(time.Unix(1700000000, 0)))

				result := env.Processor.EnrichmentService.EnrichEvent(&event)

				assert.True(t, result.Success())
				enriched := result.Value()
				assert.Equal(t, "contract123", enriched.Contract.ID)
				assert.Equal(t, "bm123", enriched.BillableMetric.ID)
				assert.Equal(t, "contract_ext_id", enriched.ExternalContractID)
				assert.Equal(t, "tx_1", enriched.TransactionID)
				assert.Equal(t, "sum", enriched.AggregationType)
				assert.Equal(t, "12.0", *enriched.Value)
				assert.Equal(t, 1741007009.0, enriched.Timestamp)
			})

			t.Run("keeps the event without a contract when none serves it", func(t *testing.T) {
				env := setupTestEnv(t, mode.useCache)
				defer env.Cleanup()

				event := buildEvent()
				env.DataStore.SetBillableMetric(buildBillableMetric())
				env.DataStore.ExpectContractNotFound()

				result := env.Processor.EnrichmentService.EnrichEvent(&event)

				assert.True(t, result.Success())
				assert.Nil(t, result.Value().Contract)
				assert.Equal(t, "contract_ext_id", result.Value().ExternalContractID)
			})

			t.Run("falls back on the current contract for a recurring metric", func(t *testing.T) {
				env := setupTestEnv(t, mode.useCache)
				defer env.Cleanup()

				event := buildEvent()
				bm := buildBillableMetric()
				bm.Recurring = true
				env.DataStore.SetBillableMetric(bm)

				// Started after the event: only the lookup at the current time finds it.
				env.DataStore.ExpectContractNotFound()
				env.DataStore.SetContract(buildContract(time.Unix(1741007009, 0).AddDate(0, 0, 1)))

				result := env.Processor.EnrichmentService.EnrichEvent(&event)

				assert.True(t, result.Success())
				assert.Equal(t, "contract123", result.Value().Contract.ID)
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
		event.ExternalSubscriptionID = "sub_id"

		result := env.Processor.EnrichmentService.EnrichEvent(&event)

		assert.False(t, result.Success())
		assert.Equal(t, "missing_external_contract_id", result.ErrorCode())
		assert.False(t, result.IsRetryable())
		assert.False(t, result.IsCapturable())
	})

	t.Run("fails and retries when the contract lookup errors", func(t *testing.T) {
		env := setupTestEnv(t, false)
		defer env.Cleanup()

		event := buildEvent()
		env.DataStore.SetBillableMetric(buildBillableMetric())
		env.DataStore.ExpectContractError()

		result := env.Processor.EnrichmentService.EnrichEvent(&event)

		assert.False(t, result.Success())
		assert.Equal(t, "fetch_contract", result.ErrorCode())
		assert.True(t, result.IsCapturable())
		assert.True(t, result.IsRetryable())
	})
}
