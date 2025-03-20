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
	pool       *pgxpool.Pool
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

	dialector := postgres.New(postgres.Config{
		Conn: stdlib.OpenDBFromPool(pool),
	})

	conn, err := OpenConnection(logger, dialector)
	if err == nil {
		conn.pool = pool
	}
	return conn, err
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

func (db *DB) Close() {
	db.pool.Close()
}
