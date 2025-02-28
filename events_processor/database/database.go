package database

import (
	"log/slog"

	slogGorm "github.com/orandin/slog-gorm"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

type DB struct {
	connection *gorm.DB
	logger     *slog.Logger
}

func NewConnection(dbUrl string) (*DB, error) {
	logger := slog.Default()
	logger = logger.With("component", "db")

	gormLogger := slogGorm.New(
		slogGorm.WithHandler(logger.Handler()),
	)

	db, err := gorm.Open(postgres.Open(dbUrl), &gorm.Config{
		Logger: gormLogger,
	})
	if err != nil {
		logger.Error("Error connecting to the database", slog.String("error", err.Error()))
		return nil, err
	}

	return &DB{connection: db, logger: logger}, nil
}
