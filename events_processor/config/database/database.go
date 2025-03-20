package database

import (
	"context"
	"log/slog"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/jackc/pgx/v5/stdlib"
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

	poolConfig, err := pgxpool.ParseConfig(dbUrl)
	if err != nil {
		return nil, err
	}

	poolConfig.MaxConns = 200

	pool, err := pgxpool.NewWithConfig(context.Background(), poolConfig)
	if err != nil {
		return nil, err
	}
	//defer pool.Close()

	dialector := postgres.New(postgres.Config{
		Conn: stdlib.OpenDBFromPool(pool),
	})

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
