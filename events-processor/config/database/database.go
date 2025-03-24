package database

import (
	"context"
	"errors"
	"log/slog"
	"net"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
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

type DBConfig struct {
	Url      string
	MaxConns int32
}

func NewConnection(config DBConfig) (*DB, error) {
	logger := slog.Default()
	logger = logger.With("component", "db")

	poolConfig, err := pgxpool.ParseConfig(config.Url)
	if err != nil {
		return nil, err
	}

	poolConfig.MaxConns = config.MaxConns

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

func IsTransientError(err error) bool {
	if err == nil {
		return false
	}

	if errors.Is(err, pgx.ErrNoRows) {
		return false
	}

	var netErr net.Error
	if errors.As(err, &netErr) {
		// Error is a network temporary error
		return true
	}

	if errors.Is(err, context.DeadlineExceeded) ||
		errors.Is(err, context.Canceled) {
		// Context cancellation and timeouts
		return true
	}

	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) {
		// Check PostgreSQL error classes that indicate temporary issues
		switch pgErr.Code[:2] {
		case "08", // Connection Exception
			"40", // Transaction Rollback
			"53", // Insufficient Resources
			"57", // Operator Intervention
			"58": // System Error
			return true
		default:
			// All other PostgreSQL errors are likely not temporary
			return false
		}
	}

	// Other errors connection errors from pgx
	msg := strings.ToLower(err.Error())
	if strings.Contains(msg, "connect") ||
		strings.Contains(msg, "timeout") ||
		strings.Contains(msg, "eof") ||
		strings.Contains(msg, "closed") {
		return true
	}

	return false
}
