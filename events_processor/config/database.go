package config

import (
	"log"
	"log/slog"
	"os"
	"time"

	"github.com/getlago/lago/events-processor/models"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

type DB struct {
	connection *gorm.DB
	logger     *slog.Logger
}

func NewConnection() (*DB, error) {
	logger := slog.Default()
	logger = logger.With("component", "db")

	db, err := gorm.Open(postgres.Open(os.Getenv("DATABASE_URL")), &gorm.Config{})
	if err != nil {
		logger.Error("Error connecting to the database", slog.String("error", err.Error()))
		log.Fatalln(err)
		return nil, err
	}

	return &DB{connection: db, logger: logger}, nil
}

func (db *DB) FetchBillableMetric(organizationID string, code string) (*models.BillableMetric, error) {
	// TODO: take deleted records into account

	var bm *models.BillableMetric
	result := db.connection.First(bm, "organization_id = ? AND code = ?", organizationID, code)
	if result.Error != nil {
		return nil, result.Error
	}

	return bm, nil
}

func (db *DB) FetchSubscription(organizationID string, externalID string, timestamp time.Time) (*models.Subscription, error) {
	var sub *models.Subscription

	var conditions = `
		customers.organization_id = ?
		subscriptions.external_id = ?
		date_trunc('millisecond', subscriptions.started_at::timestamp) <= ?::timestamp
		AND (subscriptions.terminated_at IS NULL OR date_trunc('millisecond', subscriptions.terminated_at::timestamp) >= ?)
	`
	result := db.connection.
		Joins("INNER JOIN customers ON customers.id = subscriptions.customer_id").
		Order("terminated_at DESC NULLS FIRST, started_at DESC").
		First(sub, conditions, organizationID, externalID, timestamp, timestamp)

	if result.Error != nil {
		return nil, result.Error
	}

	return sub, nil
}

func (db *DB) AnyInAdvanceCharge(planID string, billableMetricID string) (bool, error) {
	// TODO: take deleted records into account
	var count int64

	result := db.connection.Model(&models.Charge{}).
		Where("plan_id = ? AND billable_metric_id = ?", planID, billableMetricID).
		Count(&count)
	if result.Error != nil {
		return false, result.Error
	}

	return count > 0, nil
}
