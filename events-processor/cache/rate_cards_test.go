package cache

import (
	"encoding/json"
	"testing"

	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/utils"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/twmb/franz-go/pkg/kgo"
)

func setAdvanceCatalog(t *testing.T, cache *Cache, billingTiming, productType, billableMetricID string) {
	require.True(t, cache.SetContractRateCard(&models.ContractRateCard{
		ID: "crc123", OrganizationID: "org-123", ContractID: "contract123", RateCardID: "rc123",
	}).Success())
	require.True(t, cache.SetRateCard(&models.RateCard{
		ID: "rc123", OrganizationID: "org-123", ProductID: "product123", BillingTiming: billingTiming,
	}).Success())
	require.True(t, cache.SetProduct(&models.Product{
		ID: "product123", OrganizationID: "org-123", BillableMetricID: &billableMetricID, ProductType: productType,
	}).Success())
}

func TestHasAdvanceRateCard(t *testing.T) {
	t.Run("is true for an advance rate card on a metered product of the metric", func(t *testing.T) {
		cache := setupTestCache(t)
		setAdvanceCatalog(t, cache, models.RateCardBillingTimingAdvance, models.ProductTypeMetered, "bm123")

		result := cache.HasAdvanceRateCard("org-123", "contract123", "bm123")

		require.True(t, result.Success())
		assert.True(t, result.Value())
	})

	t.Run("is false for an arrears rate card", func(t *testing.T) {
		cache := setupTestCache(t)
		setAdvanceCatalog(t, cache, "arrears", models.ProductTypeMetered, "bm123")

		result := cache.HasAdvanceRateCard("org-123", "contract123", "bm123")

		require.True(t, result.Success())
		assert.False(t, result.Value())
	})

	t.Run("is false for another metric or a fixed product", func(t *testing.T) {
		cache := setupTestCache(t)
		setAdvanceCatalog(t, cache, models.RateCardBillingTimingAdvance, models.ProductTypeMetered, "bm-other")

		assert.False(t, cache.HasAdvanceRateCard("org-123", "contract123", "bm123").Value())

		setAdvanceCatalog(t, cache, models.RateCardBillingTimingAdvance, "fixed", "bm123")

		assert.False(t, cache.HasAdvanceRateCard("org-123", "contract123", "bm123").Value())
	})

	t.Run("is false for another contract", func(t *testing.T) {
		cache := setupTestCache(t)
		setAdvanceCatalog(t, cache, models.RateCardBillingTimingAdvance, models.ProductTypeMetered, "bm123")

		result := cache.HasAdvanceRateCard("org-123", "contract-other", "bm123")

		require.True(t, result.Success())
		assert.False(t, result.Value())
	})

	t.Run("is false when the rate card is not cached yet", func(t *testing.T) {
		cache := setupTestCache(t)
		require.True(t, cache.SetContractRateCard(&models.ContractRateCard{
			ID: "crc123", OrganizationID: "org-123", ContractID: "contract123", RateCardID: "rc123",
		}).Success())

		result := cache.HasAdvanceRateCard("org-123", "contract123", "bm123")

		require.True(t, result.Success())
		assert.False(t, result.Value())
	})
}

func catalogRecord(t *testing.T, model any) *kgo.Record {
	data, err := json.Marshal(model)
	require.NoError(t, err)

	return &kgo.Record{Value: data, Topic: "test_topic"}
}

func TestRateCardConsumers(t *testing.T) {
	t.Run("drops a contract rate card once deleted", func(t *testing.T) {
		cache := setupTestCache(t)
		setAdvanceCatalog(t, cache, models.RateCardBillingTimingAdvance, models.ProductTypeMetered, "bm123")

		deleted := &models.ContractRateCard{
			ID: "crc123", OrganizationID: "org-123", ContractID: "contract123", RateCardID: "rc123",
			DeletedAt: utils.NowNullTime(),
		}
		processRecord(cache, catalogRecord(t, deleted), cache.contractRateCardsConsumerConfig())

		assert.True(t, cache.GetContractRateCard("org-123", "contract123", "crc123").Failure())
		assert.False(t, cache.HasAdvanceRateCard("org-123", "contract123", "bm123").Value())
	})

	t.Run("follows a rate card moving to arrears", func(t *testing.T) {
		cache := setupTestCache(t)
		setAdvanceCatalog(t, cache, models.RateCardBillingTimingAdvance, models.ProductTypeMetered, "bm123")

		updated := &models.RateCard{
			ID: "rc123", OrganizationID: "org-123", ProductID: "product123", BillingTiming: "arrears",
			UpdatedAt: utils.NowNullTime(),
		}
		processRecord(cache, catalogRecord(t, updated), cache.rateCardsConsumerConfig())

		assert.False(t, cache.HasAdvanceRateCard("org-123", "contract123", "bm123").Value())
	})

	t.Run("drops a product once deleted", func(t *testing.T) {
		cache := setupTestCache(t)
		setAdvanceCatalog(t, cache, models.RateCardBillingTimingAdvance, models.ProductTypeMetered, "bm123")

		billableMetricID := "bm123"
		deleted := &models.Product{
			ID: "product123", OrganizationID: "org-123", BillableMetricID: &billableMetricID,
			ProductType: models.ProductTypeMetered, DeletedAt: utils.NowNullTime(),
		}
		processRecord(cache, catalogRecord(t, deleted), cache.productsConsumerConfig())

		assert.True(t, cache.GetProduct("org-123", "product123").Failure())
	})
}
