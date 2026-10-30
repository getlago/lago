package models

import (
	"gorm.io/gorm"

	"github.com/getlago/lago/events-processor/utils"
)

const (
	RateCardBillingTimingAdvance = "advance"
	ProductTypeMetered           = "metered"
)

// ContractRateCard attaches a rate card to a contract.
type ContractRateCard struct {
	ID             string         `gorm:"primaryKey;->" json:"id"`
	OrganizationID string         `gorm:"->" json:"organization_id"`
	ContractID     string         `gorm:"->" json:"contract_id"`
	RateCardID     string         `gorm:"->" json:"rate_card_id"`
	CreatedAt      utils.NullTime `gorm:"->" json:"created_at"`
	UpdatedAt      utils.NullTime `gorm:"->" json:"updated_at"`
	DeletedAt      utils.NullTime `gorm:"->" json:"deleted_at"`
}

type RateCard struct {
	ID             string         `gorm:"primaryKey;->" json:"id"`
	OrganizationID string         `gorm:"->" json:"organization_id"`
	ProductID      string         `gorm:"->" json:"product_id"`
	BillingTiming  string         `gorm:"->" json:"billing_timing"`
	CreatedAt      utils.NullTime `gorm:"->" json:"created_at"`
	UpdatedAt      utils.NullTime `gorm:"->" json:"updated_at"`
	DeletedAt      utils.NullTime `gorm:"->" json:"deleted_at"`
}

type Product struct {
	ID               string         `gorm:"primaryKey;->" json:"id"`
	OrganizationID   string         `gorm:"->" json:"organization_id"`
	BillableMetricID *string        `gorm:"->" json:"billable_metric_id"`
	ProductType      string         `gorm:"->" json:"product_type"`
	CreatedAt        utils.NullTime `gorm:"->" json:"created_at"`
	UpdatedAt        utils.NullTime `gorm:"->" json:"updated_at"`
	DeletedAt        utils.NullTime `gorm:"->" json:"deleted_at"`
}

// HasAdvanceRateCard reports whether one of the contract's rate cards bills the
// billable metric in advance. It ignores rate versions and effective dates: the
// API prices the event exactly, so a false positive only costs an empty job.
func (store *ApiStore) HasAdvanceRateCard(organizationID string, contractID string, billableMetricID string) utils.Result[bool] {
	var ids []string

	result := store.db.Connection.
		Table("contract_rate_cards").
		Select("contract_rate_cards.id").
		Joins("JOIN rate_cards ON rate_cards.id = contract_rate_cards.rate_card_id").
		Joins("JOIN products ON products.id = rate_cards.product_id").
		Where(
			`contract_rate_cards.organization_id = ?
			AND contract_rate_cards.contract_id = ?
			AND contract_rate_cards.deleted_at IS NULL
			AND rate_cards.deleted_at IS NULL
			AND rate_cards.billing_timing = ?
			AND products.deleted_at IS NULL
			AND products.product_type = ?
			AND products.billable_metric_id = ?`,
			organizationID,
			contractID,
			RateCardBillingTimingAdvance,
			ProductTypeMetered,
			billableMetricID,
		).
		Limit(1).
		Find(&ids)
	if result.Error != nil {
		return utils.FailedBoolResult(result.Error)
	}

	return utils.SuccessResult(len(ids) > 0)
}

func GetAllContractRateCards(db *gorm.DB) utils.Result[[]ContractRateCard] {
	return GetAllWithStreaming[ContractRateCard](db, StreamQueryConfig{
		TableName:      "contract_rate_cards",
		SelectFields:   []string{"id", "organization_id", "contract_id", "rate_card_id", "created_at", "updated_at", "deleted_at"},
		WhereCondition: "deleted_at IS NULL",
		WhereArgs:      []any{},
		LogInterval:    50000,
	})
}

func GetAllRateCards(db *gorm.DB) utils.Result[[]RateCard] {
	return GetAllWithStreaming[RateCard](db, StreamQueryConfig{
		TableName:      "rate_cards",
		SelectFields:   []string{"id", "organization_id", "product_id", "billing_timing", "created_at", "updated_at", "deleted_at"},
		WhereCondition: "deleted_at IS NULL",
		WhereArgs:      []any{},
		LogInterval:    50000,
	})
}

func GetAllProducts(db *gorm.DB) utils.Result[[]Product] {
	return GetAllWithStreaming[Product](db, StreamQueryConfig{
		TableName:      "products",
		SelectFields:   []string{"id", "organization_id", "billable_metric_id", "product_type", "created_at", "updated_at", "deleted_at"},
		WhereCondition: "deleted_at IS NULL",
		WhereArgs:      []any{},
		LogInterval:    50000,
	})
}
