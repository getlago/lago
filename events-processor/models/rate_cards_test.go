package models

import (
	"errors"
	"regexp"
	"testing"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/stretchr/testify/assert"
)

var hasAdvanceRateCardQuery = regexp.QuoteMeta(`
	SELECT contract_rate_cards.id FROM "contract_rate_cards"
	JOIN rate_cards ON rate_cards.id = contract_rate_cards.rate_card_id
	JOIN products ON products.id = rate_cards.product_id
	WHERE contract_rate_cards.organization_id = $1
		AND contract_rate_cards.contract_id = $2
		AND contract_rate_cards.deleted_at IS NULL
		AND rate_cards.deleted_at IS NULL
		AND rate_cards.billing_timing = $3
		AND products.deleted_at IS NULL
		AND products.product_type = $4
		AND products.billable_metric_id = $5
	LIMIT $6`,
)

func TestHasAdvanceRateCard(t *testing.T) {
	orgID := "1a901a90-1a90-1a90-1a90-1a901a901a90"

	t.Run("is true when a contract rate card bills the metric in advance", func(t *testing.T) {
		store, mock, cleanup := setupApiStore(t)
		defer cleanup()

		mock.ExpectQuery(hasAdvanceRateCardQuery).
			WithArgs(orgID, "contract123", "advance", "metered", "bm123", 1).
			WillReturnRows(sqlmock.NewRows([]string{"id"}).AddRow("crc123"))

		result := store.HasAdvanceRateCard(orgID, "contract123", "bm123")

		assert.True(t, result.Success())
		assert.True(t, result.Value())
		assert.NoError(t, mock.ExpectationsWereMet())
	})

	t.Run("is false without such a rate card", func(t *testing.T) {
		store, mock, cleanup := setupApiStore(t)
		defer cleanup()

		mock.ExpectQuery(hasAdvanceRateCardQuery).
			WithArgs(orgID, "contract123", "advance", "metered", "bm123", 1).
			WillReturnRows(sqlmock.NewRows([]string{"id"}))

		result := store.HasAdvanceRateCard(orgID, "contract123", "bm123")

		assert.True(t, result.Success())
		assert.False(t, result.Value())
	})

	t.Run("returns a retryable error when the database fails", func(t *testing.T) {
		store, mock, cleanup := setupApiStore(t)
		defer cleanup()

		dbError := errors.New("database connection failed")
		mock.ExpectQuery(hasAdvanceRateCardQuery).WillReturnError(dbError)

		result := store.HasAdvanceRateCard(orgID, "contract123", "bm123")

		assert.False(t, result.Success())
		assert.Equal(t, dbError, result.Error())
		assert.True(t, result.IsRetryable())
	})
}
