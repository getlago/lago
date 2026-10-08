package cache

import (
	"encoding/json"
	"testing"
	"time"

	"github.com/dgraph-io/badger/v4"
	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/utils"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/twmb/franz-go/pkg/kgo"
)

func buildContract(id string, startedAt time.Time) *models.Contract {
	orgID := "org-123"
	return &models.Contract{
		ID:             id,
		OrganizationID: &orgID,
		ExternalID:     "contract-ext",
		CreatedAt:      utils.NowNullTime(),
		UpdatedAt:      utils.NowNullTime(),
		StartedAt:      utils.NewNullTime(startedAt),
	}
}

func TestBuildContractKey(t *testing.T) {
	cache := setupTestCache(t)

	assert.Equal(t, "contract:org-123:contract-ext:123", cache.buildContractKey("org-123", "contract-ext", "123"))
}

func TestSetContract_NilOrganizationID(t *testing.T) {
	cache := setupTestCache(t)

	contract := &models.Contract{ID: "123", ExternalID: "contract-ext"}
	result := cache.SetContract(contract)

	assert.True(t, result.Failure())
	assert.Contains(t, result.Error().Error(), "nil OrganizationID")
}

func TestSearchContracts(t *testing.T) {
	timestamp := time.Date(2026, 10, 15, 12, 0, 0, 0, time.UTC)

	t.Run("returns the contract started before the timestamp", func(t *testing.T) {
		cache := setupTestCache(t)
		require.True(t, cache.SetContract(buildContract("started", timestamp.AddDate(0, -1, 0))).Success())
		require.True(t, cache.SetContract(buildContract("future", timestamp.AddDate(0, 0, 1))).Success())

		result := cache.SearchContracts("org-123", "contract-ext", timestamp)

		require.True(t, result.Success())
		assert.Equal(t, "started", result.Value().ID)
	})

	t.Run("prefers the active contract to a pending one", func(t *testing.T) {
		cache := setupTestCache(t)
		active := buildContract("active", timestamp.AddDate(0, -2, 0))
		active.Status = models.ContractStatusActive
		pending := buildContract("pending", timestamp.AddDate(0, -1, 0))
		pending.Status = "pending"
		require.True(t, cache.SetContract(active).Success())
		require.True(t, cache.SetContract(pending).Success())

		result := cache.SearchContracts("org-123", "contract-ext", timestamp)

		require.True(t, result.Success())
		assert.Equal(t, "active", result.Value().ID)
	})

	t.Run("prefers the live contract to the one it replaced", func(t *testing.T) {
		cache := setupTestCache(t)
		replaced := buildContract("replaced", timestamp.AddDate(0, -2, 0))
		replaced.TerminatedAt = utils.NewNullTime(timestamp.AddDate(0, 0, 1))
		require.True(t, cache.SetContract(replaced).Success())
		require.True(t, cache.SetContract(buildContract("live", timestamp.AddDate(0, -1, 0))).Success())

		result := cache.SearchContracts("org-123", "contract-ext", timestamp)

		require.True(t, result.Success())
		assert.Equal(t, "live", result.Value().ID)
	})

	t.Run("returns a terminated contract for its own late events", func(t *testing.T) {
		cache := setupTestCache(t)
		terminated := buildContract("terminated", timestamp.AddDate(0, -2, 0))
		terminated.TerminatedAt = utils.NewNullTime(timestamp.AddDate(0, 0, 1))
		require.True(t, cache.SetContract(terminated).Success())

		result := cache.SearchContracts("org-123", "contract-ext", timestamp)

		require.True(t, result.Success())
		assert.Equal(t, "terminated", result.Value().ID)
	})

	t.Run("ignores contracts terminated before the timestamp or canceled", func(t *testing.T) {
		cache := setupTestCache(t)
		terminated := buildContract("terminated", timestamp.AddDate(0, -2, 0))
		terminated.TerminatedAt = utils.NewNullTime(timestamp.AddDate(0, 0, -1))
		canceled := buildContract("canceled", timestamp.AddDate(0, -1, 0))
		canceled.CanceledAt = utils.NewNullTime(timestamp.AddDate(0, -1, 0))
		require.True(t, cache.SetContract(terminated).Success())
		require.True(t, cache.SetContract(canceled).Success())

		result := cache.SearchContracts("org-123", "contract-ext", timestamp)

		assert.True(t, result.Failure())
		assert.ErrorIs(t, result.Error(), badger.ErrKeyNotFound)
		assert.False(t, result.IsCapturable())
		assert.False(t, result.IsRetryable())
	})
}

func TestDeleteContract(t *testing.T) {
	t.Run("drops a canceled contract", func(t *testing.T) {
		cache := setupTestCache(t)
		contract := buildContract("canceled", time.Now())
		contract.CanceledAt = utils.NowNullTime()
		require.True(t, cache.SetContract(contract).Success())

		require.True(t, cache.DeleteContract(contract).Success())

		assert.True(t, cache.GetContract("org-123", "contract-ext", "canceled").Failure())
	})

	t.Run("keeps a terminated contract for its late events", func(t *testing.T) {
		cache := setupTestCache(t)
		contract := buildContract("terminated", time.Now().AddDate(0, -1, 0))
		contract.TerminatedAt = utils.NowNullTime()
		require.True(t, cache.SetContract(contract).Success())

		require.True(t, cache.DeleteContract(contract).Success())

		assert.True(t, cache.GetContract("org-123", "contract-ext", "terminated").Success())
	})
}

func contractRecord(t *testing.T, contract *models.Contract) *kgo.Record {
	data, err := json.Marshal(contract)
	require.NoError(t, err)

	return &kgo.Record{Value: data, Topic: "test_topic"}
}

func TestContractsConsumer(t *testing.T) {
	t.Run("caches a new contract", func(t *testing.T) {
		cache := setupTestCache(t)
		contract := buildContract("new", time.Now())

		processRecord(cache, contractRecord(t, contract), cache.contractsConsumerConfig())

		assert.True(t, cache.GetContract("org-123", "contract-ext", "new").Success())
	})

	t.Run("drops a contract once canceled", func(t *testing.T) {
		cache := setupTestCache(t)
		contract := buildContract("canceled", time.Now())
		require.True(t, cache.SetContract(contract).Success())

		canceled := buildContract("canceled", time.Now())
		canceled.CanceledAt = utils.NowNullTime()
		processRecord(cache, contractRecord(t, canceled), cache.contractsConsumerConfig())

		assert.True(t, cache.GetContract("org-123", "contract-ext", "canceled").Failure())
	})

	t.Run("keeps a contract once terminated, with its termination date", func(t *testing.T) {
		cache := setupTestCache(t)
		contract := buildContract("terminated", time.Now().AddDate(0, -1, 0))
		require.True(t, cache.SetContract(contract).Success())

		terminated := buildContract("terminated", time.Now().AddDate(0, -1, 0))
		terminated.TerminatedAt = utils.NowNullTime()
		processRecord(cache, contractRecord(t, terminated), cache.contractsConsumerConfig())

		result := cache.GetContract("org-123", "contract-ext", "terminated")
		require.True(t, result.Success())
		assert.True(t, result.Value().TerminatedAt.Valid)
	})
}
