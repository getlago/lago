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

var fetchSubscriptionQuery = regexp.QuoteMeta(`
	SELECT
	"subscriptions"."id","subscriptions"."external_id","subscriptions"."plan_id","subscriptions"."created_at","subscriptions"."updated_at","subscriptions"."started_at","subscriptions"."terminated_at"
	FROM "subscriptions"
		INNER JOIN customers ON customers.id = subscriptions.customer_id
	WHERE customers.organization_id = $1
		AND subscriptions.external_id = $2
		AND date_trunc('millisecond', subscriptions.started_at::timestamp) <= $3::timestamp
		AND (subscriptions.terminated_at IS NULL OR date_trunc('millisecond', subscriptions.terminated_at::timestamp) >= $4)
	ORDER BY terminated_at DESC NULLS FIRST, started_at DESC LIMIT $5`,
)

func TestFetchSubscription(t *testing.T) {
	t.Run("should return subscription when found", func(t *testing.T) {
		// Setup
		store, mock, cleanup := setupApiStore(t)
		defer cleanup()

		orgID := "1a901a90-1a90-1a90-1a90-1a901a901a90"
		externalID := "1a901a90-1a90-1a90-1a90-1a901a901a91"
		timestamp := time.Now()

		// Define expected rows and columns
		columns := []string{"id", "external_id", "plan_id", "created_at", "updated_at", "started_at", "terminated_at"}
		rows := sqlmock.NewRows(columns).
			AddRow("sub123", externalID, "plan123", timestamp, timestamp, timestamp, timestamp)

		// Expect the query
		mock.ExpectQuery(fetchSubscriptionQuery).
			WithArgs(orgID, externalID, timestamp, timestamp, 1).
			WillReturnRows(rows)

		// Execute
		result := store.FetchSubscription(orgID, externalID, timestamp)

		// Assert
		assert.True(t, result.Success())

		sub := result.Value()
		assert.NotNil(t, sub)
		assert.Equal(t, "sub123", sub.ID)
		assert.Equal(t, externalID, sub.ExternalID)
		assert.Equal(t, "plan123", sub.PlanID)
	})

	t.Run("should return error subscription not found", func(t *testing.T) {
		// Setup
		store, mock, cleanup := setupApiStore(t)
		defer cleanup()

		orgID := "1a901a90-1a90-1a90-1a90-1a901a901a90"
		externalID := "1a901a90-1a90-1a90-1a90-1a901a901a91"
		timestamp := time.Now()

		// Expect the query but return error
		mock.ExpectQuery(fetchSubscriptionQuery).
			WithArgs(orgID, externalID, timestamp, timestamp, 1).
			WillReturnError(gorm.ErrRecordNotFound)

		// Execute
		result := store.FetchSubscription(orgID, externalID, timestamp)

		// Assert
		assert.False(t, result.Success())
		assert.NotNil(t, result.Error())
		assert.Equal(t, gorm.ErrRecordNotFound, result.Error())
		assert.Nil(t, result.Value())
		assert.False(t, result.IsCapturable())
		assert.False(t, result.IsRetryable())
	})

	t.Run("should handle database connection error", func(t *testing.T) {
		// Setup
		store, mock, cleanup := setupApiStore(t)
		defer cleanup()

		orgID := "1a901a90-1a90-1a90-1a90-1a901a901a90"
		externalID := "1a901a90-1a90-1a90-1a90-1a901a901a91"
		timestamp := time.Now()
		dbError := errors.New("database connection failed")

		// Expect the query but return error
		mock.ExpectQuery(fetchSubscriptionQuery).
			WithArgs(orgID, externalID, timestamp, timestamp, 1).
			WillReturnError(dbError)

		// Execute
		result := store.FetchSubscription(orgID, externalID, timestamp)

		// Assert
		assert.False(t, result.Success())
		assert.NotNil(t, result.Error())
		assert.Equal(t, dbError, result.Error())
		assert.Nil(t, result.Value())
		assert.True(t, result.IsCapturable())
		assert.True(t, result.IsRetryable())
	})
}
