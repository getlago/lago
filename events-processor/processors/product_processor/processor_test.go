package product_processor

import (
	"context"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/twmb/franz-go/pkg/kgo"
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
