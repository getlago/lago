package cache

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/dgraph-io/badger/v4"
	"github.com/getlago/lago/events-processor/models"
	"github.com/getlago/lago/events-processor/utils"
	"gorm.io/gorm"
)

const (
	contractPrefix    = "contract"
	contractModelName = "contracts"
	contractTopic     = ".public.contracts"
)

func (c *Cache) buildContractKey(organizationID, externalID, ID string) string {
	return fmt.Sprintf("%s:%s:%s:%s", contractPrefix, organizationID, externalID, ID)
}

func (c *Cache) contractKey(contract *models.Contract) (string, error) {
	if contract.OrganizationID == nil {
		return "", fmt.Errorf("contract %s has nil OrganizationID", contract.ID)
	}
	return c.buildContractKey(*contract.OrganizationID, contract.ExternalID, contract.ID), nil
}

func (c *Cache) SetContract(contract *models.Contract) utils.Result[bool] {
	key, err := c.contractKey(contract)
	if err != nil {
		return utils.FailedBoolResult(err)
	}
	return setJSON(c, key, contract)
}

func (c *Cache) GetContract(organizationID, externalID, ID string) utils.Result[*models.Contract] {
	key := c.buildContractKey(organizationID, externalID, ID)
	return getJSON[models.Contract](c, key)
}

// SearchContracts mirrors ApiStore.FetchContract: among the contracts started at
// timestamp and not terminated before it, the live one wins, then the latest
// terminated, then the latest started.
func (c *Cache) SearchContracts(organizationID string, externalID string, timestamp time.Time) utils.Result[*models.Contract] {
	prefix := fmt.Sprintf("%s:%s:%s:", contractPrefix, organizationID, externalID)
	result := searchJSON[models.Contract](c, prefix)
	if result.Failure() {
		return utils.FailedResult[*models.Contract](result.Error())
	}

	var bestMatch *models.Contract
	for _, contract := range result.Value() {
		if !servesTimestamp(contract, timestamp) {
			continue
		}

		if bestMatch == nil || preferContract(contract, bestMatch) {
			bestMatch = contract
		}
	}

	if bestMatch == nil {
		return utils.FailedResult[*models.Contract](badger.ErrKeyNotFound).
			NonCapturable().NonRetryable()
	}

	c.logger.Debug("search contract result", slog.String("contract external id", bestMatch.ExternalID))
	return utils.SuccessResult(bestMatch)
}

func servesTimestamp(contract *models.Contract, timestamp time.Time) bool {
	if contract.CanceledAt.Valid || !contract.StartedAt.Valid || contract.StartedAt.Time.After(timestamp) {
		return false
	}

	return !contract.TerminatedAt.Valid || !contract.TerminatedAt.Time.Before(timestamp)
}

// preferContract orders like "terminated_at DESC NULLS FIRST, started_at DESC".
func preferContract(candidate, current *models.Contract) bool {
	if candidate.TerminatedAt.Valid != current.TerminatedAt.Valid {
		return !candidate.TerminatedAt.Valid
	}

	if candidate.TerminatedAt.Valid && !candidate.TerminatedAt.Time.Equal(current.TerminatedAt.Time) {
		return candidate.TerminatedAt.Time.After(current.TerminatedAt.Time)
	}

	return candidate.StartedAt.Time.After(current.StartedAt.Time)
}

// DeleteContract drops a canceled contract, which never served an event, and
// keeps a terminated one for a month so its late events still resolve.
func (c *Cache) DeleteContract(contract *models.Contract) utils.Result[bool] {
	key, err := c.contractKey(contract)
	if err != nil {
		return utils.FailedBoolResult(err)
	}

	if contract.CanceledAt.Valid {
		return delete(c, key)
	}

	return deleteWithTTL(c, key, contract, 30*24*time.Hour)
}

func (c *Cache) LoadContractsSnapshot(db *gorm.DB) utils.Result[int] {
	return LoadSnapshot(
		c,
		contractModelName,
		func() ([]models.Contract, error) {
			res := models.GetAllContracts(db)
			if res.Failure() {
				return nil, res.Error()
			}
			return res.Value(), nil
		},
		func(contract *models.Contract) string {
			key, err := c.contractKey(contract)
			if err != nil {
				c.logger.Error("Skipping contract in snapshot", slog.String("error", err.Error()))
				return ""
			}
			return key
		},
	)
}

func (c *Cache) StartContractsConsumer(ctx context.Context) error {
	return startGenericConsumer(ctx, c, ConsumerConfig[models.Contract]{
		Topic:     c.debeziumTopicPrefix + contractTopic,
		ModelName: contractModelName,
		IsDeleted: func(contract *models.Contract) bool {
			return contract.TerminatedAt.Valid || contract.CanceledAt.Valid
		},
		GetKey: func(contract *models.Contract) string {
			key, _ := c.contractKey(contract)
			return key
		},
		GetID: func(contract *models.Contract) string {
			return contract.ID
		},
		GetUpdatedAt: func(contract *models.Contract) int64 {
			return contract.UpdatedAt.Time.UnixMilli()
		},
		GetCached: func(contract *models.Contract) utils.Result[*models.Contract] {
			if contract.OrganizationID == nil {
				return utils.FailedResult[*models.Contract](fmt.Errorf("contract %s has nil OrganizationID", contract.ID))
			}
			return c.GetContract(*contract.OrganizationID, contract.ExternalID, contract.ID)
		},
		SetCache: func(contract *models.Contract) utils.Result[bool] {
			return c.SetContract(contract)
		},
		Delete: func(contract *models.Contract) utils.Result[bool] {
			return c.DeleteContract(contract)
		},
	})
}
