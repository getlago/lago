package models

import (
	"errors"
	"regexp"
	"testing"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/stretchr/testify/assert"
)

// Written out rather than built from advanceRateCardQuery, so that a change to the rule
// fails these tests. gorm sends it with Postgres placeholders.
var hasAdvanceRateCardQuery = regexp.QuoteMeta(`SELECT contract_rate_cards.id
FROM contract_rate_cards
JOIN contracts ON contracts.id = contract_rate_cards.contract_id
JOIN rate_cards ON rate_cards.id = contract_rate_cards.rate_card_id
JOIN products ON products.id = rate_cards.product_id
WHERE contracts.organization_id = $1
	AND contracts.external_id = $2
	AND contracts.status = 'active'
	AND contract_rate_cards.deleted_at IS NULL
	AND rate_cards.billing_timing = 'advance'
	AND products.product_type = 'metered'
	AND products.billable_metric_id = $3
LIMIT 1`)

func TestHasAdvanceRateCard(t *testing.T) {
	orgID := "1a901a90-1a90-1a90-1a90-1a901a901a90"
	externalContractID := "contract_ext_id"
	billableMetricID := "bm123"

	t.Run("returns true when the active contract has an advance rate card for the metric", func(t *testing.T) {
		store, mock, cleanup := setupApiStore(t)
		defer cleanup()

		mock.ExpectQuery(hasAdvanceRateCardQuery).
			WithArgs(orgID, externalContractID, billableMetricID).
			WillReturnRows(sqlmock.NewRows([]string{"id"}).AddRow("crc123"))

		result := store.HasAdvanceRateCard(orgID, externalContractID, billableMetricID)

		assert.True(t, result.Success())
		assert.True(t, result.Value())
		assert.NoError(t, mock.ExpectationsWereMet())
	})

	t.Run("returns false when no rate card of the contract is billed in advance", func(t *testing.T) {
		store, mock, cleanup := setupApiStore(t)
		defer cleanup()

		mock.ExpectQuery(hasAdvanceRateCardQuery).
			WithArgs(orgID, externalContractID, billableMetricID).
			WillReturnRows(sqlmock.NewRows([]string{"id"}))

		result := store.HasAdvanceRateCard(orgID, externalContractID, billableMetricID)

		assert.True(t, result.Success())
		assert.False(t, result.Value())
	})

	t.Run("fails when the query fails", func(t *testing.T) {
		store, mock, cleanup := setupApiStore(t)
		defer cleanup()

		mock.ExpectQuery(hasAdvanceRateCardQuery).
			WithArgs(orgID, externalContractID, billableMetricID).
			WillReturnError(errors.New("connection refused"))

		result := store.HasAdvanceRateCard(orgID, externalContractID, billableMetricID)

		assert.False(t, result.Success())
		assert.Equal(t, "connection refused", result.ErrorMsg())
	})
}
