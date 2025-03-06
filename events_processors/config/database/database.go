package database

import (
	"log/slog"

	slogGorm "github.com/orandin/slog-gorm"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

type DB struct {
	Connection *gorm.DB
	logger     *slog.Logger
}

func NewConnection(dbUrl string) (*DB, error) {
	logger := slog.Default()
	logger = logger.With("component", "db")

	dialector := postgres.Open(dbUrl)

	return OpenConnection(logger, dialector)
}

func OpenConnection(logger *slog.Logger, dialector gorm.Dialector) (*DB, error) {
	gormLogger := slogGorm.New(
		slogGorm.WithHandler(logger.Handler()),
	)

	db, err := gorm.Open(dialector, &gorm.Config{
		Logger: gormLogger,
	})

	if err != nil {
		return nil, err
	}

	return &DB{Connection: db, logger: logger}, nil
}
