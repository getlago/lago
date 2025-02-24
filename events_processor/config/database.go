package config

import (
	"log"
	"log/slog"
	"os"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

type DB struct {
	connection *gorm.DB
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

	return &DB{connection: db}, nil
}
