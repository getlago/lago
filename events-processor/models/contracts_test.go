package models

import (
	"errors"
	"regexp"
	"testing"
	"time"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/stretchr/testify/assert"
	"gorm.io/gorm"
)

var fetchContractQuery = regexp.QuoteMeta(`
	SELECT "id","organization_id","external_id","status","created_at","updated_at","started_at","terminated_at","canceled_at"
	FROM "contracts"
	WHERE contracts.organization_id = $1
		AND contracts.external_id = $2
		AND contracts.canceled_at IS NULL
		AND date_trunc('millisecond', contracts.started_at::timestamp) <= $3::timestamp
		AND (contracts.terminated_at IS NULL OR date_trunc('millisecond', contracts.terminated_at::timestamp) >= $4)
	ORDER BY terminated_at DESC NULLS FIRST, (status = 'active') DESC, started_at DESC LIMIT $5`,
)

func TestFetchContract(t *testing.T) {
	orgID := "1a901a90-1a90-1a90-1a90-1a901a901a90"
	externalID := "contract_ext_id"

	t.Run("should return the contract when found", func(t *testing.T) {
		store, mock, cleanup := setupApiStore(t)
		defer cleanup()

		timestamp := time.Now()
		columns := []string{"id", "organization_id", "external_id", "status", "created_at", "updated_at", "started_at", "terminated_at", "canceled_at"}
		rows := sqlmock.NewRows(columns).
			AddRow("contract123", orgID, externalID, "active", timestamp, timestamp, timestamp, nil, nil)

		mock.ExpectQuery(fetchContractQuery).
			WithArgs(orgID, externalID, timestamp, timestamp, 1).
			WillReturnRows(rows)

		result := store.FetchContract(orgID, externalID, timestamp)

		assert.True(t, result.Success())
		assert.Equal(t, "contract123", result.Value().ID)
		assert.Equal(t, externalID, result.Value().ExternalID)
		assert.Equal(t, ContractStatusActive, result.Value().Status)
	})

	t.Run("should return a non capturable error when not found", func(t *testing.T) {
		store, mock, cleanup := setupApiStore(t)
		defer cleanup()

		timestamp := time.Now()
		mock.ExpectQuery(fetchContractQuery).
			WithArgs(orgID, externalID, timestamp, timestamp, 1).
			WillReturnRows(sqlmock.NewRows([]string{"id"}))

		result := store.FetchContract(orgID, externalID, timestamp)

		assert.False(t, result.Success())
		assert.Equal(t, gorm.ErrRecordNotFound, result.Error())
		assert.False(t, result.IsCapturable())
		assert.False(t, result.IsRetryable())
	})

	t.Run("should return a retryable error when the database fails", func(t *testing.T) {
		store, mock, cleanup := setupApiStore(t)
		defer cleanup()

		timestamp := time.Now()
		dbError := errors.New("database connection failed")
		mock.ExpectQuery(fetchContractQuery).
			WithArgs(orgID, externalID, timestamp, timestamp, 1).
			WillReturnError(dbError)

		result := store.FetchContract(orgID, externalID, timestamp)

		assert.False(t, result.Success())
		assert.Equal(t, dbError, result.Error())
		assert.True(t, result.IsCapturable())
		assert.True(t, result.IsRetryable())
	})
}

func TestGetAllContracts(t *testing.T) {
	t.Run("loads live contracts and those terminated less than a month ago", func(t *testing.T) {
		store, mock, cleanup := setupApiStore(t)
		defer cleanup()

		now := time.Now()
		columns := []string{"id", "organization_id", "external_id", "status", "created_at", "updated_at", "started_at", "terminated_at", "canceled_at"}
		rows := sqlmock.NewRows(columns).
			AddRow("contract123", "org-123", "contract_ext_id", "active", now, now, now, nil, nil)

		mock.ExpectQuery(regexp.QuoteMeta(
			`SELECT id,organization_id,external_id,status,created_at,updated_at,started_at,terminated_at,canceled_at FROM "contracts" WHERE canceled_at IS NULL AND (terminated_at IS NULL OR terminated_at >= $1)`,
		)).WithArgs(sqlmock.AnyArg()).WillReturnRows(rows)

		result := GetAllContracts(store.db.Connection)

		assert.True(t, result.Success())
		assert.Len(t, result.Value(), 1)
		assert.Equal(t, "contract123", result.Value()[0].ID)
		assert.NoError(t, mock.ExpectationsWereMet())
	})
}
