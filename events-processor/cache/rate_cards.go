package cache

import (
	"context"
	"errors"
	"fmt"

	"github.com/dgraph-io/badger/v4"
	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/utils"
	"gorm.io/gorm"
)

const (
	contractRateCardPrefix    = "crc"
	contractRateCardModelName = "contract_rate_cards"
	contractRateCardTopic     = ".public.contract_rate_cards"

	rateCardPrefix    = "rc"
	rateCardModelName = "rate_cards"
	rateCardTopic     = ".public.rate_cards"

	productPrefix    = "product"
	productModelName = "products"
	productTopic     = ".public.products"
)

// Contract rate cards are keyed by contract so a contract's cards are one prefix scan.
func (c *Cache) buildContractRateCardKey(organizationID, contractID, id string) string {
	return fmt.Sprintf("%s:%s:%s:%s", contractRateCardPrefix, organizationID, contractID, id)
}

func (c *Cache) buildRateCardKey(organizationID, id string) string {
	return fmt.Sprintf("%s:%s:%s", rateCardPrefix, organizationID, id)
}

func (c *Cache) buildProductKey(organizationID, id string) string {
	return fmt.Sprintf("%s:%s:%s", productPrefix, organizationID, id)
}

func (c *Cache) SetContractRateCard(crc *models.ContractRateCard) utils.Result[bool] {
	return setJSON(c, c.buildContractRateCardKey(crc.OrganizationID, crc.ContractID, crc.ID), crc)
}

func (c *Cache) GetContractRateCard(organizationID, contractID, id string) utils.Result[*models.ContractRateCard] {
	return getJSON[models.ContractRateCard](c, c.buildContractRateCardKey(organizationID, contractID, id))
}

func (c *Cache) SetRateCard(rc *models.RateCard) utils.Result[bool] {
	return setJSON(c, c.buildRateCardKey(rc.OrganizationID, rc.ID), rc)
}

func (c *Cache) GetRateCard(organizationID, id string) utils.Result[*models.RateCard] {
	return getJSON[models.RateCard](c, c.buildRateCardKey(organizationID, id))
}

func (c *Cache) SetProduct(p *models.Product) utils.Result[bool] {
	return setJSON(c, c.buildProductKey(p.OrganizationID, p.ID), p)
}

func (c *Cache) GetProduct(organizationID, id string) utils.Result[*models.Product] {
	return getJSON[models.Product](c, c.buildProductKey(organizationID, id))
}

// HasAdvanceRateCard mirrors ApiStore.HasAdvanceRateCard. The tables come from
// separate Debezium topics, so a contract card can be cached before its rate card
// or product. That is only lag, since the API refuses to delete a rate card or a
// product a contract card uses: the event is retried instead of being judged as
// not billed in advance. Lag on the contract itself or on its contract cards is
// not detected, as it can't be told apart from a contract that doesn't exist or
// has no card: like a subscription missing from the cache, the event is then not
// sent to price in advance.
func (c *Cache) HasAdvanceRateCard(organizationID, contractID, billableMetricID string) utils.Result[bool] {
	prefix := fmt.Sprintf("%s:%s:%s:", contractRateCardPrefix, organizationID, contractID)
	cardsResult := searchJSON[models.ContractRateCard](c, prefix)
	if cardsResult.Failure() {
		return utils.FailedBoolResult(cardsResult.Error())
	}

	for _, contractRateCard := range cardsResult.Value() {
		rateCardResult := c.GetRateCard(organizationID, contractRateCard.RateCardID)
		if rateCardResult.Failure() {
			if errors.Is(rateCardResult.Error(), badger.ErrKeyNotFound) {
				return notCachedYet("rate card", contractRateCard.RateCardID)
			}
			return utils.FailedBoolResult(rateCardResult.Error())
		}

		rateCard := rateCardResult.Value()
		if rateCard.BillingTiming != models.RateCardBillingTimingAdvance {
			continue
		}

		productResult := c.GetProduct(organizationID, rateCard.ProductID)
		if productResult.Failure() {
			if errors.Is(productResult.Error(), badger.ErrKeyNotFound) {
				return notCachedYet("product", rateCard.ProductID)
			}
			return utils.FailedBoolResult(productResult.Error())
		}

		product := productResult.Value()
		if product.ProductType == models.ProductTypeMetered &&
			product.BillableMetricID != nil && *product.BillableMetricID == billableMetricID {
			return utils.SuccessResult(true)
		}
	}

	return utils.SuccessResult(false)
}

// notCachedYet is retried, without reaching Sentry: an event still failing after
// the retry window goes to the dead letter queue.
func notCachedYet(model, id string) utils.Result[bool] {
	return utils.FailedBoolResult(fmt.Errorf("%s %s is not cached yet", model, id)).NonCapturable()
}

func (c *Cache) LoadContractRateCardsSnapshot(db *gorm.DB) utils.Result[int] {
	return LoadSnapshot(
		c,
		contractRateCardModelName,
		func() ([]models.ContractRateCard, error) {
			res := models.GetAllContractRateCards(db)
			if res.Failure() {
				return nil, res.Error()
			}
			return res.Value(), nil
		},
		func(crc *models.ContractRateCard) string {
			return c.buildContractRateCardKey(crc.OrganizationID, crc.ContractID, crc.ID)
		},
	)
}

func (c *Cache) LoadRateCardsSnapshot(db *gorm.DB) utils.Result[int] {
	return LoadSnapshot(
		c,
		rateCardModelName,
		func() ([]models.RateCard, error) {
			res := models.GetAllRateCards(db)
			if res.Failure() {
				return nil, res.Error()
			}
			return res.Value(), nil
		},
		func(rc *models.RateCard) string {
			return c.buildRateCardKey(rc.OrganizationID, rc.ID)
		},
	)
}

func (c *Cache) LoadProductsSnapshot(db *gorm.DB) utils.Result[int] {
	return LoadSnapshot(
		c,
		productModelName,
		func() ([]models.Product, error) {
			res := models.GetAllProducts(db)
			if res.Failure() {
				return nil, res.Error()
			}
			return res.Value(), nil
		},
		func(p *models.Product) string {
			return c.buildProductKey(p.OrganizationID, p.ID)
		},
	)
}

func (c *Cache) StartContractRateCardsConsumer(ctx context.Context) error {
	return startGenericConsumer(ctx, c, c.contractRateCardsConsumerConfig())
}

func (c *Cache) StartRateCardsConsumer(ctx context.Context) error {
	return startGenericConsumer(ctx, c, c.rateCardsConsumerConfig())
}

func (c *Cache) StartProductsConsumer(ctx context.Context) error {
	return startGenericConsumer(ctx, c, c.productsConsumerConfig())
}

func (c *Cache) contractRateCardsConsumerConfig() ConsumerConfig[models.ContractRateCard] {
	key := func(crc *models.ContractRateCard) string {
		return c.buildContractRateCardKey(crc.OrganizationID, crc.ContractID, crc.ID)
	}

	return ConsumerConfig[models.ContractRateCard]{
		Topic:        c.debeziumTopicPrefix + contractRateCardTopic,
		ModelName:    contractRateCardModelName,
		IsDeleted:    func(crc *models.ContractRateCard) bool { return crc.DeletedAt.Valid },
		GetKey:       key,
		GetID:        func(crc *models.ContractRateCard) string { return crc.ID },
		GetUpdatedAt: func(crc *models.ContractRateCard) int64 { return crc.UpdatedAt.Time.UnixMilli() },
		GetCached: func(crc *models.ContractRateCard) utils.Result[*models.ContractRateCard] {
			return c.GetContractRateCard(crc.OrganizationID, crc.ContractID, crc.ID)
		},
		SetCache: c.SetContractRateCard,
		Delete:   func(crc *models.ContractRateCard) utils.Result[bool] { return delete(c, key(crc)) },
	}
}

func (c *Cache) rateCardsConsumerConfig() ConsumerConfig[models.RateCard] {
	key := func(rc *models.RateCard) string { return c.buildRateCardKey(rc.OrganizationID, rc.ID) }

	return ConsumerConfig[models.RateCard]{
		Topic:        c.debeziumTopicPrefix + rateCardTopic,
		ModelName:    rateCardModelName,
		IsDeleted:    func(rc *models.RateCard) bool { return rc.DeletedAt.Valid },
		GetKey:       key,
		GetID:        func(rc *models.RateCard) string { return rc.ID },
		GetUpdatedAt: func(rc *models.RateCard) int64 { return rc.UpdatedAt.Time.UnixMilli() },
		GetCached: func(rc *models.RateCard) utils.Result[*models.RateCard] {
			return c.GetRateCard(rc.OrganizationID, rc.ID)
		},
		SetCache: c.SetRateCard,
		Delete:   func(rc *models.RateCard) utils.Result[bool] { return delete(c, key(rc)) },
	}
}

func (c *Cache) productsConsumerConfig() ConsumerConfig[models.Product] {
	key := func(p *models.Product) string { return c.buildProductKey(p.OrganizationID, p.ID) }

	return ConsumerConfig[models.Product]{
		Topic:        c.debeziumTopicPrefix + productTopic,
		ModelName:    productModelName,
		IsDeleted:    func(p *models.Product) bool { return p.DeletedAt.Valid },
		GetKey:       key,
		GetID:        func(p *models.Product) string { return p.ID },
		GetUpdatedAt: func(p *models.Product) int64 { return p.UpdatedAt.Time.UnixMilli() },
		GetCached: func(p *models.Product) utils.Result[*models.Product] {
			return c.GetProduct(p.OrganizationID, p.ID)
		},
		SetCache: c.SetProduct,
		Delete:   func(p *models.Product) utils.Result[bool] { return delete(c, key(p)) },
	}
}
