package database

import (
	"log/slog"
	"os"
	"testing"
	"time"

	"github.com/DATA-DOG/go-sqlmock"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

func setupMockDB(t *testing.T) (*DB, sqlmock.Sqlmock, func()) {
	mockDB, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("Failed to create mock database: %v", err)
	}

	dialector := postgres.New(postgres.Config{
		Conn:       mockDB,
		DriverName: "postgres",
	})

	silentLogger := logger.Config{
		SlowThreshold:             time.Second,
		LogLevel:                  logger.Silent,
		IgnoreRecordNotFoundError: true,
		Colorful:                  false,
	}

	gormDB, err := gorm.Open(dialector, &gorm.Config{
		Logger: logger.New(nil, silentLogger),
	})
	if err != nil {
		t.Fatalf("Failed to open gorm connection: %v", err)
	}

	logger := slog.New(slog.NewJSONHandler(os.Stderr, &slog.HandlerOptions{Level: slog.Level(-4)}))

	db := &DB{
		connection: gormDB,
		logger:     logger,
	}

	return db, mock, func() {
		mockDB.Close()
	}
}
