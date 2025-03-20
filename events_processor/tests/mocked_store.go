package tests

import (
	"log/slog"
	"os"
	"testing"

	"github.com/DATA-DOG/go-sqlmock"
	"gorm.io/driver/postgres"

	"github.com/getlago/lago/events-processor/config/database"
)

func SetupMockStore(t *testing.T) (*database.DB, sqlmock.Sqlmock, func()) {
	mockDB, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("Failed to create mock database: %v", err)
	}

	dialector := postgres.New(postgres.Config{
		Conn:       mockDB,
		DriverName: "postgres",
	})

	logger := slog.New(slog.NewJSONHandler(os.Stderr, &slog.HandlerOptions{Level: slog.Level(-4)}))

	db, err := database.OpenConnection(logger, dialector)
	if err != nil {
		t.Fatalf("Failed to open gorm connection: %v", err)
	}

	return db, mock, func() {
		mockDB.Close()
	}
}
