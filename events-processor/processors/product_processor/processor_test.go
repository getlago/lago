package product_processor

import (
	"context"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/twmb/franz-go/pkg/kgo"

	"github.com/getlago/lago/events-processor/models"
)

func TestProcessEvent(t *testing.T) {
	for _, mode := range testModes {
		t.Run(mode.name, func(t *testing.T) {
			t.Run("writes the enriched event", func(t *testing.T) {
				env := setupTestEnv(t, mode.useCache)
				defer env.Cleanup()

				event := buildEvent()
				env.DataStore.SetBillableMetric(buildBillableMetric())

				result := env.Processor.processEvent(context.Background(), &event)

				require.True(t, result.Success())
				assert.Equal(t, 1, env.Producers.enriched.ExecutionCount)
				assert.Equal(t, 0, env.Producers.deadLetter.ExecutionCount)
			})

			t.Run("does not produce anything when enrichment fails", func(t *testing.T) {
				env := setupTestEnv(t, mode.useCache)
				defer env.Cleanup()

				env.DataStore.ExpectBillableMetricNotFound()

				event := buildEvent()
				result := env.Processor.processEvent(context.Background(), &event)

				assert.False(t, result.Success())
				assert.Equal(t, "fetch_billable_metric", result.ErrorCode())
				assert.Equal(t, 0, env.Producers.enriched.ExecutionCount)
			})
		})
	}
}

func TestProcessEventChargedInAdvance(t *testing.T) {
	for _, mode := range testModes {
		t.Run(mode.name, func(t *testing.T) {
			t.Run("produces the event when the contract has an advance rate card for the metric", func(t *testing.T) {
				env := setupTestEnvChargingInAdvance(t, mode.useCache)
				defer env.Cleanup()

				env.DataStore.SetBillableMetric(buildBillableMetric())
				env.DataStore.ExpectAdvanceRateCard(true)

				event := buildEvent()
				result := env.Processor.processEvent(context.Background(), &event)

				require.True(t, result.Success())
				assert.Equal(t, 1, env.Producers.enriched.ExecutionCount)
				assert.Equal(t, 1, env.Producers.inAdvance.ExecutionCount)
				assert.Equal(t, []byte(orgID+"-tx_1"), env.Producers.inAdvance.Key)
			})

			t.Run("does not produce the event when no rate card of the contract is billed in advance", func(t *testing.T) {
				env := setupTestEnvChargingInAdvance(t, mode.useCache)
				defer env.Cleanup()

				env.DataStore.SetBillableMetric(buildBillableMetric())
				env.DataStore.ExpectAdvanceRateCard(false)

				event := buildEvent()
				result := env.Processor.processEvent(context.Background(), &event)

				require.True(t, result.Success())
				assert.Equal(t, 1, env.Producers.enriched.ExecutionCount)
				assert.Equal(t, 0, env.Producers.inAdvance.ExecutionCount)
			})

			t.Run("does not look the rate cards up for an event the API already post processed", func(t *testing.T) {
				env := setupTestEnvChargingInAdvance(t, mode.useCache)
				defer env.Cleanup()

				env.DataStore.SetBillableMetric(buildBillableMetric())

				event := buildEvent()
				event.Source = models.HTTP_RUBY
				event.SourceMetadata = &models.SourceMetadata{ApiPostProcess: true}
				result := env.Processor.processEvent(context.Background(), &event)

				// No lookup was expected: an unexpected query would fail the result.
				require.True(t, result.Success())
				assert.Equal(t, 1, env.Producers.enriched.ExecutionCount)
				assert.Equal(t, 0, env.Producers.inAdvance.ExecutionCount)
			})

			t.Run("does not look the rate cards up without the in advance topic", func(t *testing.T) {
				env := setupTestEnv(t, mode.useCache)
				defer env.Cleanup()

				env.DataStore.SetBillableMetric(buildBillableMetric())

				event := buildEvent()
				result := env.Processor.processEvent(context.Background(), &event)

				require.True(t, result.Success())
				assert.Equal(t, 1, env.Producers.enriched.ExecutionCount)
				assert.Equal(t, 0, env.Producers.inAdvance.ExecutionCount)
			})

			t.Run("fails when the rate cards can't be looked up", func(t *testing.T) {
				env := setupTestEnvChargingInAdvance(t, mode.useCache)
				defer env.Cleanup()

				env.DataStore.SetBillableMetric(buildBillableMetric())
				env.DataStore.ExpectAdvanceRateCardError()

				event := buildEvent()
				result := env.Processor.processEvent(context.Background(), &event)

				assert.False(t, result.Success())
				assert.Equal(t, "fetch_advance_rate_card", result.ErrorCode())
				assert.Equal(t, 0, env.Producers.inAdvance.ExecutionCount)
			})
		})
	}
}

func TestProcessEvents(t *testing.T) {
	env := setupTestEnv(t, true)
	defer env.Cleanup()

	env.DataStore.SetBillableMetric(buildBillableMetric())

	valid := buildEvent()
	withoutContract := valid
	withoutContract.ExternalContractID = ""
	withoutContract.TransactionID = "tx_2"

	records := []*kgo.Record{
		eventRecord(t, 1, valid),
		eventRecord(t, 2, withoutContract),
		{Value: []byte("not json"), Offset: 3},
	}

	processed := env.Processor.ProcessEvents(context.Background(), records)

	// Every record is committed: the valid one is enriched, the one without a
	// contract id goes to the dead letter queue although it was just ingested
	// (it is not retried), and unparsable JSON is skipped.
	assert.Len(t, processed, 3)
	assert.Equal(t, 1, env.Producers.enriched.ExecutionCount)
	assert.Equal(t, 1, env.Producers.deadLetter.ExecutionCount)
}
