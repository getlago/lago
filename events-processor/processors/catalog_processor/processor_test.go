package catalog_processor

import (
	"context"
	"encoding/json"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/twmb/franz-go/pkg/kgo"
	"gorm.io/gorm"

	"github.com/getlago/lago/events-processor/models"
)

func TestProcessEvent(t *testing.T) {
	bm := buildBillableMetric()
	contract := buildContract(time.Unix(1700000000, 0))

	for _, mode := range testModes {
		t.Run(mode.name, func(t *testing.T) {
			t.Run("without a contract, only writes the enriched event", func(t *testing.T) {
				env := setupTestEnv(t, mode.useCache)
				defer env.Cleanup()

				event := buildEvent()
				env.DataStore.SetBillableMetric(bm)
				env.DataStore.ExpectContractNotFound()

				result := env.Processor.processEvent(context.Background(), &event)

				require.True(t, result.Success())
				assert.Nil(t, result.Value().Contract)
				assert.Equal(t, 1, env.Producers.enriched.ExecutionCount)
				assert.Equal(t, 0, env.Producers.inAdvance.ExecutionCount)
			})

			t.Run("with an advance rate card, sends the event to price in advance", func(t *testing.T) {
				env := setupTestEnv(t, mode.useCache)
				defer env.Cleanup()

				event := buildEvent()
				env.DataStore.SetBillableMetric(bm)
				env.DataStore.SetContract(contract)
				env.DataStore.SetAdvanceRateCard(orgID, contract.ID, bm.ID, true)

				result := env.Processor.processEvent(context.Background(), &event)

				require.True(t, result.Success())
				assert.Equal(t, "contract123", result.Value().Contract.ID)
				assert.Equal(t, 1, env.Producers.enriched.ExecutionCount)
				assert.Equal(t, 1, env.Producers.inAdvance.ExecutionCount)

				// The API job finds the contract through external_subscription_id.
				var payload map[string]any
				require.NoError(t, json.Unmarshal(env.Producers.inAdvance.Value, &payload))
				assert.Equal(t, "contract_ext_id", payload["external_subscription_id"])
				assert.Equal(t, "tx_1", payload["transaction_id"])
				assert.Equal(t, "12.0", payload["value"])
			})

			t.Run("with an arrears rate card, sends nothing to price", func(t *testing.T) {
				env := setupTestEnv(t, mode.useCache)
				defer env.Cleanup()

				event := buildEvent()
				env.DataStore.SetBillableMetric(bm)
				env.DataStore.SetContract(contract)
				env.DataStore.SetAdvanceRateCard(orgID, contract.ID, bm.ID, false)

				result := env.Processor.processEvent(context.Background(), &event)

				require.True(t, result.Success())
				assert.Equal(t, 1, env.Producers.enriched.ExecutionCount)
				assert.Equal(t, 0, env.Producers.inAdvance.ExecutionCount)
			})

			t.Run("when the API already post-processed the event, sends nothing to price", func(t *testing.T) {
				env := setupTestEnv(t, mode.useCache)
				defer env.Cleanup()

				event := buildEvent()
				event.Source = models.HTTP_RUBY
				event.SourceMetadata = &models.SourceMetadata{ApiPostProcess: true}
				env.DataStore.SetBillableMetric(bm)
				env.DataStore.SetContract(contract)

				result := env.Processor.processEvent(context.Background(), &event)

				require.True(t, result.Success())
				assert.Equal(t, 1, env.Producers.enriched.ExecutionCount)
				assert.Equal(t, 0, env.Producers.inAdvance.ExecutionCount)
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

	t.Run("fails and retries when the advance lookup errors", func(t *testing.T) {
		env := setupTestEnv(t, false)
		defer env.Cleanup()

		event := buildEvent()
		env.DataStore.SetBillableMetric(bm)
		env.DataStore.SetContract(contract)
		env.DataStore.(*MockDataStore).mock.SQLMock.
			ExpectQuery(".* FROM \"contract_rate_cards\".*").
			WillReturnError(gorm.ErrNotImplemented)

		result := env.Processor.processEvent(context.Background(), &event)

		assert.False(t, result.Success())
		assert.Equal(t, "fetch_advance_rate_card", result.ErrorCode())
		assert.True(t, result.IsRetryable())
		assert.Equal(t, 0, env.Producers.inAdvance.ExecutionCount)
	})
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
